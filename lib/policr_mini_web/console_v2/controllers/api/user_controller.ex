defmodule PolicrMiniWeb.ConsoleV2.API.UserController do
  use PolicrMiniWeb, :controller

  alias PolicrMini.Schema.User
  alias PolicrMiniBot.Helper

  action_fallback PolicrMiniWeb.ConsoleV2.API.FallbackController

  def me(conn, _params) do
    render(conn, "show.json", user: refresh_telegram_photo(conn.assigns[:user]))
  end

  defp refresh_telegram_photo(%User{} = user) do
    case Helper.sync_user_photo(user) do
      {:ok, refreshed_user} -> refreshed_user
      _ -> user
    end
  end

  defp refresh_telegram_photo(user), do: user
end
