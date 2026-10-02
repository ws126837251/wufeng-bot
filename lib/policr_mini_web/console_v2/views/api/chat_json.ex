defmodule PolicrMiniWeb.ConsoleV2.API.ChatView do
  use PolicrMiniWeb, :view
  use PolicrMiniWeb.ConsoleV2.Helpers, :view

  alias PolicrMini.Instances.Chat
  alias PolicrMini.Uses

  alias PolicrMiniWeb.ConsoleV2.API.{
    StatsView,
    SchemeView,
    CustomView,
    VerificationView,
    OperationView
  }

  def render("index.json", %{chats: chats, user: user}) when is_list(chats) do
    success(Enum.map(chats, &chat_payload(&1, user.id)))
  end

  def render("show.json", %{chat: chat, user: user}) when is_struct(chat, Chat) do
    success(chat_payload(chat, user.id))
  end

  def render("chat.json", %{chat: chat}) when is_struct(chat, Chat) do
    chat_payload(chat, nil)
  end

  defp chat_payload(chat, user_id) do
    permission = if user_id, do: Uses.get_permission(chat.id, user_id)

    %{
      id: chat.id,
      title: chat.title,
      username: chat.username,
      description: chat.description,
      big_photo_id: chat.big_photo_id,
      taken_over: chat.is_take_over,
      left: chat.left,
      inserted_at: chat.inserted_at,
      access_role: access_role(permission),
      can_configure:
        permission != nil and (permission.configurable || permission.tg_is_owner),
      can_operate: permission != nil and (permission.writable || permission.tg_is_owner)
    }
  end

  defp access_role(%{tg_is_owner: true}), do: "owner"
  defp access_role(%{}), do: "administrator"
  defp access_role(nil), do: "none"

  def render("stats.json", %{stats: stats}) do
    success(render_one(stats, StatsView, "stats.json"))
  end

  def render("scheme.json", %{scheme: scheme}) do
    success(render_one(scheme, SchemeView, "scheme.json"))
  end

  def render("customs.json", %{customs: customs}) when is_list(customs) do
    success(render_many(customs, CustomView, "custom.json"))
  end

  def render("verifications.json", %{verifications: verifications}) when is_list(verifications) do
    success(render_many(verifications, VerificationView, "verification.json"))
  end

  def render("operations.json", %{operations: operations}) when is_list(operations) do
    success(render_many(operations, OperationView, "operation.json"))
  end
end
