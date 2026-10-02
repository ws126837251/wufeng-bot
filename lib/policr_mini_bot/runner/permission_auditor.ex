defmodule PolicrMiniBot.Runner.PermissionAuditor do
  @moduledoc false

  alias PolicrMini.{BotHealth, Uses}

  require Logger

  def run do
    Uses.find_taken_over_chats()
    |> Enum.each(fn chat ->
      case BotHealth.audit(chat) do
        {:ok, %{status: "healthy"}} ->
          :ok

        {:ok, %{status: status, last_audit: audit}} ->
          Logger.warning(
            "Permission audit requires attention: #{inspect(status: status, missing: audit.missing_permissions, error: audit.last_error)}",
            chat_id: chat.id
          )

        {:error, reason} ->
          Logger.warning("Permission audit failed: #{inspect(reason)}", chat_id: chat.id)
      end
    end)

    :ok
  end
end
