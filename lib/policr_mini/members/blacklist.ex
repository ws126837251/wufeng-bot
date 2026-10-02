defmodule PolicrMini.Members.Blacklist do
  @moduledoc false

  import Ecto.Query

  alias PolicrMini.Members.{ActionLog, BlacklistEntry, GroupMember}
  alias PolicrMini.Repo

  require Logger

  def list(chat_id, limit \\ 100) do
    from(entry in BlacklistEntry,
      where: entry.chat_id == ^chat_id and entry.active == true,
      order_by: [desc: entry.updated_at],
      limit: ^min(max(limit, 1), 200)
    )
    |> Repo.all()
    |> Enum.map(&entry_map/1)
  end

  def active?(chat_id, user_id) do
    Repo.exists?(
      from(entry in BlacklistEntry,
        where: entry.chat_id == ^chat_id and entry.user_id == ^user_id and entry.active == true
      )
    )
  end

  def put(chat_id, actor_user_id, user, reason) do
    now = now()

    attrs = %{
      chat_id: chat_id,
      user_id: user.id,
      actor_user_id: actor_user_id,
      target_display_name: display_name(user),
      target_username: Map.get(user, :username),
      reason: blank_to_nil(reason),
      active: true,
      enforced_at: nil,
      last_error: nil,
      removed_by_user_id: nil,
      removed_at: nil
    }

    updates = attrs |> Map.drop([:chat_id, :user_id]) |> Map.put(:updated_at, now)

    %BlacklistEntry{}
    |> BlacklistEntry.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: Map.to_list(updates)],
      conflict_target: [:chat_id, :user_id],
      returning: true
    )
  end

  def mark_enforced(chat_id, user_id) do
    update_entry(chat_id, user_id, %{enforced_at: now(), last_error: nil})
  end

  def mark_failed(chat_id, user_id, error) do
    update_entry(chat_id, user_id, %{
      enforced_at: nil,
      last_error: error |> telegram_error() |> String.slice(0, 1000)
    })
  end

  def remove(chat_id, actor_user_id, user_id) do
    with %BlacklistEntry{} = entry <- active_entry(chat_id, user_id),
         {:ok, true} <- Telegex.unban_chat_member(chat_id, user_id),
         {:ok, entry} <- deactivate(entry, actor_user_id) do
      mark_member_left(chat_id, user_id)
      log_action(entry, actor_user_id, "unblock", "success", nil)
      {:ok, entry_map(entry)}
    else
      nil -> {:error, :not_blacklisted}
      {:error, error} -> {:error, telegram_error(error)}
    end
  end

  def reject_join_request(chat_id, user_id) do
    case Telegex.decline_chat_join_request(chat_id, user_id) do
      {:ok, true} ->
        :ok

      {:error, error} ->
        mark_failed(chat_id, user_id, error)
        {:error, telegram_error(error)}
    end
  end

  def reject_joined_member(chat_id, user_id) do
    case enforce_member(chat_id, user_id) do
      {:ok, true} ->
        mark_member_kicked(chat_id, user_id)
        :ok

      {:error, error} ->
        {:error, telegram_error(error)}
    end
  end

  def enforce_member(chat_id, user_id) do
    case Telegex.ban_chat_member(chat_id, user_id) do
      {:ok, true} ->
        verify_enforced(chat_id, user_id)

      {:error, error} ->
        mark_failed(chat_id, user_id, error)
        {:error, error}
    end
  end

  @doc false
  def banned_member?(%{status: "kicked"}), do: true
  def banned_member?(_member), do: false

  def enforce_pending do
    entries =
      from(entry in BlacklistEntry,
        where: entry.active == true and is_nil(entry.enforced_at),
        order_by: [asc: entry.inserted_at],
        limit: 100
      )
      |> Repo.all()

    Enum.each(entries, fn entry ->
      case reject_joined_member(entry.chat_id, entry.user_id) do
        :ok ->
          :ok

        {:error, error} ->
          Logger.warning("Blacklist enforcement failed: #{error}", chat_id: entry.chat_id)
      end
    end)

    :ok
  end

  defp active_entry(chat_id, user_id) do
    Repo.one(
      from(entry in BlacklistEntry,
        where: entry.chat_id == ^chat_id and entry.user_id == ^user_id and entry.active == true
      )
    )
  end

  defp verify_enforced(chat_id, user_id) do
    case Telegex.get_chat_member(chat_id, user_id) do
      {:ok, member} ->
        if banned_member?(member) do
          mark_enforced(chat_id, user_id)
          {:ok, true}
        else
          mark_failed(chat_id, user_id, :ban_status_not_confirmed)
          {:error, :ban_status_not_confirmed}
        end

      {:error, error} ->
        mark_failed(chat_id, user_id, error)
        {:error, error}
    end
  end

  defp deactivate(entry, actor_user_id) do
    entry
    |> BlacklistEntry.changeset(%{
      active: false,
      removed_by_user_id: actor_user_id,
      removed_at: now(),
      last_error: nil
    })
    |> Repo.update()
  end

  defp update_entry(chat_id, user_id, attrs) do
    now = now()

    from(entry in BlacklistEntry,
      where: entry.chat_id == ^chat_id and entry.user_id == ^user_id and entry.active == true
    )
    |> Repo.update_all(set: Map.to_list(Map.put(attrs, :updated_at, now)))

    :ok
  end

  defp mark_member_kicked(chat_id, user_id),
    do: update_member(chat_id, user_id, "kicked", "member_blacklist")

  defp mark_member_left(chat_id, user_id),
    do: update_member(chat_id, user_id, "left", "blacklist_removed")

  defp update_member(chat_id, user_id, status, source) do
    from(member in GroupMember,
      where: member.chat_id == ^chat_id and member.user_id == ^user_id
    )
    |> Repo.update_all(set: [status: status, source: source, updated_at: now()])
  end

  defp log_action(entry, actor_id, action, status, error) do
    attrs = %{
      chat_id: entry.chat_id,
      actor_user_id: actor_id,
      target_user_id: entry.user_id,
      target_display_name: entry.target_display_name,
      target_username: entry.target_username,
      action: action,
      reason: entry.reason,
      status: status,
      telegram_error: error
    }

    %ActionLog{} |> ActionLog.changeset(attrs) |> Repo.insert()
  end

  defp entry_map(entry) do
    %{
      id: entry.id,
      chat_id: entry.chat_id,
      user_id: entry.user_id,
      actor_user_id: entry.actor_user_id,
      full_name: entry.target_display_name || "用户 #{entry.user_id}",
      username: entry.target_username,
      photo_url: "/console/v2/#{entry.user_id}/photo",
      reason: entry.reason,
      enforced_at: entry.enforced_at,
      last_error: entry.last_error,
      inserted_at: entry.inserted_at
    }
  end

  defp display_name(user) do
    [Map.get(user, :first_name), Map.get(user, :last_name)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
    |> case do
      "" -> "用户 #{user.id}"
      name -> name
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value),
    do: if(String.trim(to_string(value)) == "", do: nil, else: String.trim(to_string(value)))

  defp telegram_error(%Telegex.Error{description: description}), do: description

  defp telegram_error(%Telegex.RequestError{reason: reason}),
    do: "Telegram请求失败：#{inspect(reason)}"

  defp telegram_error(:ban_status_not_confirmed), do: "Telegram未确认成员已经被移出"
  defp telegram_error(value) when is_binary(value), do: value
  defp telegram_error(value), do: inspect(value, limit: 10)
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
