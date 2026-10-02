defmodule PolicrMini.Members.Sync do
  @moduledoc false

  import Ecto.Query

  alias PolicrMini.Members
  alias PolicrMini.Members.{GroupMember, SyncState}
  alias PolicrMini.Repo

  require Logger

  @script "/home/policr_mini/member_sync.py"
  @stale_after_seconds 900

  def configured? do
    present?(System.get_env("TELEGRAM_API_ID")) and
      present?(System.get_env("TELEGRAM_API_HASH")) and
      present?(System.get_env("POLICR_MINI_BOT_TOKEN"))
  end

  def status(chat_id) do
    state = Repo.get(SyncState, chat_id)
    indexed_count = active_count(chat_id)

    %{
      chat_id: chat_id,
      configured: configured?(),
      status: state && state.status || "idle",
      telegram_count: state && state.telegram_count || 0,
      indexed_count: indexed_count,
      last_started_at: state && state.last_started_at,
      last_completed_at: state && state.last_completed_at,
      last_error: state && state.last_error
    }
  end

  def start(chat_id) do
    cond do
      not configured?() ->
        {:error, :not_configured}

      running?(Repo.get(SyncState, chat_id)) ->
        {:error, :already_running}

      true ->
        with {:ok, _state} <- mark_running(chat_id),
             {:ok, _pid} <-
               Task.Supervisor.start_child(PolicrMini.MemberSyncTaskSupervisor, fn ->
                 run(chat_id)
               end) do
          {:ok, status(chat_id)}
        end
    end
  end

  def run(chat_id) do
    :global.trans({{__MODULE__, :mtproto_session}, self()}, fn -> execute(chat_id) end)
  rescue
    error ->
      Logger.error("Full member sync crashed: #{Exception.message(error)}", chat_id: chat_id)
      mark_failed(chat_id, Exception.message(error))
  end

  defp execute(chat_id) do
    case System.cmd("python3", [@script, Integer.to_string(chat_id)], stderr_to_stdout: true) do
      {output, 0} -> process_payload(chat_id, output)
      {output, _exit_code} -> mark_failed(chat_id, extract_error(output))
    end
  end

  defp process_payload(chat_id, output) do
    with {:ok, %{"success" => true} = payload} <- Jason.decode(output),
         :ok <- ensure_complete(payload),
         {:ok, indexed_count} <- import_members(chat_id, payload["members"]) do
      complete(chat_id, payload["telegram_count"], indexed_count)
    else
      {:error, reason} -> mark_failed(chat_id, format_error(reason))
      other -> mark_failed(chat_id, format_error(other))
    end
  end

  defp ensure_complete(%{"telegram_count" => total, "fetched_count" => fetched})
       when is_integer(total) and is_integer(fetched) and total == fetched and fetched > 0,
       do: :ok

  defp ensure_complete(%{"telegram_count" => total, "fetched_count" => fetched}),
    do: {:error, "Telegram返回成员数不完整：#{fetched}/#{total}"}

  defp ensure_complete(_payload), do: {:error, "成员同步响应缺少数量信息"}

  defp import_members(chat_id, members) when is_list(members) do
    Repo.transaction(fn ->
      ids = Enum.map(members, &import_member!(chat_id, &1))
      mark_missing_left(chat_id, ids)
      active_count(chat_id)
    end)
  end

  defp import_member!(chat_id, member) do
    user = %{
      id: member["id"],
      first_name: member["first_name"],
      last_name: member["last_name"],
      username: member["username"],
      is_bot: member["is_bot"] == true
    }

    case Members.track(chat_id, user, "full_sync",
           force: true,
           status: member["status"] || "member"
         ) do
      {:ok, _member} -> user.id
      :ok -> user.id
      {:error, error} -> Repo.rollback(error)
    end
  end

  defp mark_missing_left(chat_id, ids) do
    now = now()

    from(member in GroupMember,
      where:
        member.chat_id == ^chat_id and
          member.status not in ["left", "kicked"] and
          member.user_id not in ^ids
    )
    |> Repo.update_all(set: [status: "left", source: "full_sync", updated_at: now])
  end

  defp active_count(chat_id) do
    Repo.aggregate(
      from(member in GroupMember,
        where: member.chat_id == ^chat_id and member.status not in ["left", "kicked"]
      ),
      :count
    )
  end

  defp mark_running(chat_id) do
    attrs = %{
      chat_id: chat_id,
      status: "running",
      last_started_at: now(),
      last_error: nil
    }

    %SyncState{chat_id: chat_id}
    |> SyncState.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: Map.to_list(Map.drop(attrs, [:chat_id])) ++ [updated_at: now()]],
      conflict_target: :chat_id,
      returning: true
    )
  end

  defp complete(chat_id, telegram_count, indexed_count) do
    update_state(chat_id, %{
      status: "success",
      telegram_count: telegram_count,
      indexed_count: indexed_count,
      last_completed_at: now(),
      last_error: nil
    })
  end

  defp mark_failed(chat_id, reason) do
    Logger.warning("Full member sync failed: #{reason}", chat_id: chat_id)
    update_state(chat_id, %{status: "failed", last_error: String.slice(reason, 0, 1000)})
  end

  defp update_state(chat_id, attrs) do
    case Repo.get(SyncState, chat_id) do
      nil ->
        %SyncState{chat_id: chat_id}
        |> SyncState.changeset(Map.put(attrs, :chat_id, chat_id))
        |> Repo.insert()

      state ->
        state |> SyncState.changeset(attrs) |> Repo.update()
    end
  end

  defp running?(%SyncState{status: "running", last_started_at: started_at})
       when not is_nil(started_at) do
    DateTime.diff(now(), started_at, :second) < @stale_after_seconds
  end

  defp running?(_state), do: false

  defp extract_error(output) do
    case Jason.decode(output) do
      {:ok, %{"error" => error}} -> error
      _ -> String.trim(output)
    end
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason, limit: 20)
  defp present?(value), do: is_binary(value) and String.trim(value) != ""
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
