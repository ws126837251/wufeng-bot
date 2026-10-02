defmodule PolicrMiniWeb.ConsoleV2.API.PermissionController do
  use PolicrMiniWeb, :controller

  alias PolicrMini.{PermissionBusiness, Repo, Uses}
  alias PolicrMini.Instances.Chat

  action_fallback PolicrMiniWeb.ConsoleV2.API.FallbackController

  @access_schema %{
    readable: [type: :boolean, required: true],
    writable: [type: :boolean, required: true],
    configurable: [type: :boolean, required: true]
  }

  plug :authorize_update when action in [:update]
  plug PolicrMiniWeb.ConsoleV2.ManagementApprovalGate when action in [:update]

  def index(%{assigns: %{user: user}} = conn, %{"chat_id" => chat_id}) do
    with {:ok, chat} <- Chat.get(chat_id),
         :ok <- authorize_owner(user, :manage_permissions, chat) do
      permissions = PermissionBusiness.find_list(chat_id: chat_id, preload: [:user])
      render(conn, "index.json", permissions: permissions)
    end
  end

  def update(%{assigns: %{user: user}} = conn, %{
        "chat_id" => chat_id,
        "user_id" => target_user_id
      } = params) do
    with {:ok, chat} <- Chat.get(chat_id),
         :ok <- authorize_owner(user, :update_permission, chat),
         permission when not is_nil(permission) <- Uses.get_permission(chat_id, target_user_id),
         :ok <- ensure_not_owner(permission),
         {:ok, access} <- Tarams.cast(params, @access_schema),
         {:ok, permission} <- PermissionBusiness.update(permission, normalize_access(access)) do
      render(conn, "show.json", permission: Repo.preload(permission, :user))
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp authorize_owner(user, action, chat) do
    if Canada.Can.can?(user, action, chat), do: :ok, else: {:error, :forbidden}
  end

  defp authorize_update(%{assigns: %{user: user}} = conn, _opts) do
    with {:ok, chat} <- Chat.get(conn.params["chat_id"]),
         :ok <- authorize_owner(user, :update_permission, chat) do
      conn
    else
      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{success: false, message: "只有本群群主可以管理权限"})
        |> halt()
    end
  end

  defp ensure_not_owner(%{tg_is_owner: true}), do: {:error, :owner_immutable}
  defp ensure_not_owner(_permission), do: :ok

  defp normalize_access(%{readable: false}) do
    %{readable: false, writable: false, configurable: false, customized: true}
  end

  defp normalize_access(access), do: Map.put(access, :customized, true)
end
