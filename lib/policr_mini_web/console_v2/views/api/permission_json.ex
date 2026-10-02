defmodule PolicrMiniWeb.ConsoleV2.API.PermissionView do
  use PolicrMiniWeb, :view
  use PolicrMiniWeb.ConsoleV2.Helpers, :view

  alias PolicrMini.Schema.{Permission, User}

  def render("index.json", %{permissions: permissions}) do
    success(Enum.map(permissions, &permission_payload/1))
  end

  def render("show.json", %{permission: permission}) do
    success(permission_payload(permission))
  end

  defp permission_payload(%Permission{user: %User{} = user} = permission) do
    %{
      user_id: user.id,
      full_name: User.full_name(user),
      username: user.username,
      tg_is_owner: permission.tg_is_owner,
      tg_can_restrict_members: permission.tg_can_restrict_members,
      tg_can_promote_members: permission.tg_can_promote_members,
      readable: permission.readable || permission.tg_is_owner,
      writable: permission.writable || permission.tg_is_owner,
      configurable: permission.configurable || permission.tg_is_owner,
      customized: permission.customized == true
    }
  end
end
