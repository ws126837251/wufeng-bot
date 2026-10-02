defmodule PolicrMiniWeb.ConsoleV2.ManagementApprovalGate do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn

  alias PolicrMini.ManagementApprovals

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{assigns: %{management_approval_replay: _approval}} = conn, _opts), do: conn

  def call(conn, _opts) do
    if ManagementApprovals.mutating_method?(conn.method) do
      case ManagementApprovals.requester_role(conn) do
        {:ok, role} ->
          if ManagementApprovals.approval_required?(role),
            do: request_approval(conn),
            else: conn

        {:error, :requester_lookup_failed} ->
          error(conn, "暂时无法通过 Telegram 核对你的群组身份，请稍后重试。")

        {:error, reason} ->
          error(conn, "群组身份核对失败：#{inspect(reason)}")
      end
    else
      conn
    end
  end

  defp request_approval(conn) do
    case ManagementApprovals.request_http(conn) do
      {:ok, approval} ->
        conn
        |> put_status(:accepted)
        |> Phoenix.Controller.json(ManagementApprovals.pending_payload(approval))
        |> halt()

      {:error, :owner_private_chat_unavailable} ->
        error(conn, "无法向群主发送审批通知，请群主先私聊 WuFengBot 并发送 /start。")

      {:error, :owner_not_found} ->
        error(conn, "未找到当前群主，请先在群内刷新机器人管理员权限。")

      {:error, :owner_lookup_failed} ->
        error(conn, "暂时无法核对 Telegram 当前群主，请稍后重试。")

      {:error, reason} ->
        error(conn, "审批申请创建失败：#{inspect(reason)}")
    end
  end

  defp error(conn, message) do
    conn
    |> put_status(:unprocessable_entity)
    |> Phoenix.Controller.json(%{success: false, message: message})
    |> halt()
  end
end
