defmodule PolicrMiniWeb.ConsoleV2.API.MemberController do
  use PolicrMiniWeb, :controller

  alias PolicrMini.Instances.Chat
  alias PolicrMini.Members
  alias PolicrMini.Members.Blacklist

  plug :ensure_access
  plug PolicrMiniWeb.ConsoleV2.ManagementApprovalGate when action in [:sync, :kick, :unblock]

  @search_schema %{
    query: [type: :string, default: ""],
    limit: [type: :integer, default: 30, number: [min: 1, max: 50]]
  }

  @kick_schema %{
    reason: [type: :string, default: ""]
  }

  def index(conn, %{"id" => chat_id} = params) do
    with {:ok, casted} <- Tarams.cast(params, @search_schema) do
      Members.resolve_query(parse_id(chat_id), casted.query)
      json_success(conn, Members.search(parse_id(chat_id), casted.query, casted.limit))
    else
      {:error, _errors} -> json_error(conn, "搜索参数无效")
    end
  end

  def actions(conn, %{"id" => chat_id}) do
    json_success(conn, Members.list_actions(parse_id(chat_id)))
  end

  def blacklist(conn, %{"id" => chat_id}) do
    json_success(conn, Blacklist.list(parse_id(chat_id)))
  end

  def sync_status(conn, %{"id" => chat_id}) do
    json_success(conn, Members.Sync.status(parse_id(chat_id)))
  end

  def sync(conn, %{"id" => chat_id}) do
    case Members.Sync.start(parse_id(chat_id)) do
      {:ok, status} -> json_success(conn, status)
      {:error, :already_running} -> json_error(conn, "完整成员同步正在进行中")
      {:error, :not_configured} -> json_error(conn, "服务器尚未配置 Telegram API 凭据")
      {:error, error} -> json_error(conn, inspect(error, limit: 10))
    end
  end

  def kick(
        %{assigns: %{user: actor}} = conn,
        %{
          "id" => chat_id,
          "user_id" => target_user_id
        } = params
      ) do
    with {:ok, input} <- Tarams.cast(params, @kick_schema),
         :ok <- validate_reason(input.reason),
         {:ok, chat} <- Chat.get(chat_id),
         {:ok, member} <- Members.kick(chat, actor.id, parse_id(target_user_id), input.reason) do
      json_success(conn, member)
    else
      {:error, :admin_protected} -> json_error(conn, "群主和管理员受保护，不能被机器人踢出")
      {:error, :bot_protected} -> json_error(conn, "WuFengBot自身受保护，不能被移出")
      {:error, :not_a_member} -> json_error(conn, "该用户当前不在群组中")
      {:error, :bot_permission_missing} -> json_error(conn, "WuFengBot缺少限制成员权限")
      {:error, :reason_too_long} -> json_error(conn, "处理原因不能超过200个字符")
      {:error, message} when is_binary(message) -> json_error(conn, message)
      {:error, error} -> json_error(conn, inspect(error, limit: 10))
    end
  end

  def unblock(
        %{assigns: %{user: actor}} = conn,
        %{"id" => chat_id, "user_id" => target_user_id}
      ) do
    case Blacklist.remove(parse_id(chat_id), actor.id, parse_id(target_user_id)) do
      {:ok, entry} -> json_success(conn, entry)
      {:error, :not_blacklisted} -> json_error(conn, "该用户不在当前群的黑名单中")
      {:error, message} when is_binary(message) -> json_error(conn, message)
      {:error, error} -> json_error(conn, inspect(error, limit: 10))
    end
  end

  defp ensure_access(conn, _opts) do
    chat_id = conn.params["id"]
    user = conn.assigns[:user]
    action =
      case conn.private.phoenix_action do
        :kick -> :kick_member
        :unblock -> :kick_member
        :sync -> :sync_members
        _ -> :members
      end

    with {:ok, chat} <- Chat.get(chat_id), true <- Canada.Can.can?(user, action, chat) do
      conn
    else
      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{success: false, message: "您没有该群组的成员管理权限"})
        |> halt()
    end
  end

  defp json_success(conn, payload), do: json(conn, %{success: true, payload: payload})

  defp json_error(conn, message) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{success: false, message: message})
  end

  defp parse_id(id) when is_integer(id), do: id
  defp parse_id(id) when is_binary(id), do: String.to_integer(id)

  defp validate_reason(reason) when is_binary(reason) do
    if String.length(reason) <= 200, do: :ok, else: {:error, :reason_too_long}
  end
end
