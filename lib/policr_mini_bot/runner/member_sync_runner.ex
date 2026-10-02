defmodule PolicrMiniBot.Runner.MemberSyncRunner do
  @moduledoc false

  alias PolicrMini.Members.Sync
  alias PolicrMini.Uses

  require Logger

  def run do
    if Sync.configured?() do
      Uses.find_taken_over_chats()
      |> Enum.each(fn chat ->
        case Sync.start(chat.id) do
          {:ok, _status} -> :ok
          {:error, :already_running} -> :ok
          {:error, reason} -> Logger.warning("Member sync was not started: #{inspect(reason)}")
        end
      end)
    end

    :ok
  end
end
