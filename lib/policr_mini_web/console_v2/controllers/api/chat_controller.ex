defmodule PolicrMiniWeb.ConsoleV2.API.ChatController do
  use PolicrMiniWeb, :controller

  alias PolicrMini.{BotHealth, Chats, Instances, ManagementSettings, Stats}
  alias PolicrMini.Instances.Chat

  import Canary.Plugs
  import PolicrMiniBot.Helper

  plug :authorize_resource, model: Chat, except: [:index]
  plug :authorize_copy_source when action in [:copy_settings]
  plug PolicrMiniWeb.ConsoleV2.ManagementApprovalGate when action in [:copy_settings, :takeover, :leave]

  action_fallback PolicrMiniWeb.ConsoleV2.API.FallbackController

  def index(%{assigns: %{user: user}} = conn, _params) do
    chats = Instances.find_user_chats(user.id)
    render(conn, "index.json", chats: chats, user: user)
  end

  def copy_settings(%{assigns: %{user: user}} = conn, %{"id" => target_id, "source_chat_id" => source_id}) do
    with {:ok, source_chat} <- Chat.get(source_id),
         true <- Canada.Can.can?(user, :copy_settings, source_chat),
         {:ok, copied} <- ManagementSettings.copy(source_id, target_id) do
      json(conn, %{success: true, payload: copied})
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> json(%{success: false, message: "你没有复制来源群设置的权限"})

      {:error, :same_chat} ->
        json_error(conn, "请选择另一个群组作为复制来源")

      {:error, :not_found} ->
        json_error(conn, "未找到复制来源群组")

      {:error, reason} ->
        json_error(conn, "复制设置失败：#{changeset_message(reason)}")
    end
  end

  def takeover(conn, %{"id" => chat_id, "value" => value}) do
    with {:ok, enabled} <- parse_takeover_value(value),
         {:ok, chat} <- Chat.get(chat_id),
         :ok <- check_takeover_permissions(chat_id, enabled),
         {:ok, chat} <- Instances.update_chat(chat, %{is_take_over: enabled}) do
      render(conn, "show.json", chat: chat, user: conn.assigns.user)
    else
      {:error, :invalid_value} -> json_error(conn, "无效的接管状态")
      {:error, :not_found} -> json_error(conn, "未找到群组")
      {:error, %Telegex.Error{description: description}} -> json_error(conn, description)
      {:error, message} when is_binary(message) -> json_error(conn, message)
      {:error, changeset} -> json_error(conn, changeset_message(changeset))
    end
  end

  def leave(conn, %{"id" => chat_id}) do
    case Telegex.leave_chat(chat_id) do
      {:ok, true} -> json(conn, %{success: true, payload: %{left: true}})
      {:error, %Telegex.Error{description: description}} -> json_error(conn, description)
      {:error, reason} -> json_error(conn, inspect(reason, limit: 8))
    end
  end

  @stats_schema %{
    range: [type: :string, in: ~w(today 7d 28d 90d), default: "7d"]
  }

  def stats(conn, %{"id" => chat_id} = params) do
    with {:ok, params} <- Tarams.cast(params, @stats_schema),
         {:ok, stats} <- Stats.query(stats_conds(chat_id, params)) do
      render(conn, "stats.json", stats: stats)
    end
  end

  def health(conn, %{"id" => chat_id}) do
    case BotHealth.check(chat_id) do
      {:ok, health} -> json(conn, %{success: true, payload: health})
      {:error, :not_found} -> json_error(conn, "未找到群组")
    end
  end

  defp stats_conds(chat_id, %{range: range}) do
    opts =
      case range do
        "today" ->
          [start: "-1d", every: "4h"]

        "7d" ->
          [start: "-7d", every: "1d"]

        "28d" ->
          [start: "-28d", every: "4d"]

        "90d" ->
          [start: "-90d", every: "30d"]
      end

    Keyword.put(opts, :chat_id, chat_id)
  end

  defp parse_takeover_value(value) when value in [true, "true"], do: {:ok, true}
  defp parse_takeover_value(value) when value in [false, "false"], do: {:ok, false}
  defp parse_takeover_value(_value), do: {:error, :invalid_value}

  defp check_takeover_permissions(_chat_id, false), do: :ok

  defp check_takeover_permissions(chat_id, true) do
    case Telegex.get_chat_member(chat_id, PolicrMiniBot.id()) do
      {:ok, member} ->
        cond do
          !is_administrator?(member) -> {:error, "机器人不是群组管理员"}
          !can_restrict_members?(member) -> {:error, "机器人缺少限制成员权限"}
          !can_delete_messages?(member) -> {:error, "机器人缺少删除消息权限"}
          !can_send_messages?(member) -> {:error, "机器人缺少发送消息权限"}
          true -> :ok
        end

      {:error, %Telegex.Error{description: description}} ->
        {:error, description}

      _ ->
        {:error, "无法读取机器人在群组中的权限，请稍后重试"}
    end
  end

  defp json_error(conn, message) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{success: false, message: message})
  end

  defp changeset_message(%Ecto.Changeset{} = changeset) do
    changeset.errors |> Enum.map_join("; ", fn {field, {message, _}} -> "#{field}: #{message}" end)
  end

  defp changeset_message(reason), do: inspect(reason, limit: 8)

  defp authorize_copy_source(%{assigns: %{user: user}} = conn, _opts) do
    with source_id when not is_nil(source_id) <- conn.params["source_chat_id"],
         {:ok, source_chat} <- Chat.get(source_id),
         true <- Canada.Can.can?(user, :copy_settings, source_chat) do
      conn
    else
      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{success: false, message: "你没有复制来源群设置的权限"})
        |> halt()
    end
  end

  def scheme(conn, %{"id" => chat_id}) do
    scheme =
      if scheme = Chats.get_scheme_by_chat_id(chat_id) do
        scheme
      else
        Chats.upsert_scheme!(chat_id, %{})
      end

    render(conn, "scheme.json", scheme: scheme)
  end

  def customs(conn, %{"id" => chat_id} = _params) do
    customs = Chats.find_custom_kits(chat_id)

    render(conn, "customs.json", customs: customs)
  end

  @verifications_schema %{
    offset: [type: :integer, default: 0],
    limit: [type: :integer, default: 120, number: [max: 120]],
    range: [type: :string, in: ~w(today 7d 30d), default: "7d"]
  }

  def verifications(conn, %{"id" => chat_id} = params) do
    with {:ok, params} <- Tarams.cast(params, @verifications_schema) do
      verifications = Chats.list_verifications(verifications_conds(chat_id, params))
      render(conn, "verifications.json", verifications: verifications)
    end
  end

  defp verifications_conds(chat_id, %{range: range} = params) do
    now = DateTime.utc_now()

    stop =
      case range do
        "today" ->
          DateTime.add(now, -1, :day)

        "7d" ->
          DateTime.add(now, -7, :day)

        "30d" ->
          DateTime.add(now, -30, :day)
      end

    [
      chat_id: chat_id,
      stop: stop,
      limit: params[:limit],
      offset: params[:offset]
    ]
  end

  @operations_schema %{
    offset: [type: :integer, default: 0],
    limit: [type: :integer, default: 120, number: [max: 120]],
    range: [type: :string, in: ~w(today 7d 30d), default: "7d"]
  }

  def operations(conn, %{"id" => chat_id} = params) do
    with {:ok, params} <- Tarams.cast(params, @operations_schema) do
      operations = Chats.list_operations(operations_conds(chat_id, params))
      render(conn, "operations.json", operations: operations)
    end
  end

  defp operations_conds(chat_id, %{range: range} = params) do
    now = DateTime.utc_now()

    stop =
      case range do
        "today" ->
          DateTime.add(now, -1, :day)

        "7d" ->
          DateTime.add(now, -7, :day)

        "30d" ->
          DateTime.add(now, -30, :day)
      end

    [
      chat_id: chat_id,
      stop: stop,
      limit: params[:limit],
      offset: params[:offset]
    ]
  end
end
