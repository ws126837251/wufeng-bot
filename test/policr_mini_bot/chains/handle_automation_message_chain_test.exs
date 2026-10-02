defmodule PolicrMiniBot.HandleAutomationMessageChainTest do
  use ExUnit.Case, async: true

  alias PolicrMiniBot.HandleAutomationMessageChain
  alias Telegex.Type.{Chat, Message, User}

  test "reads sender id from a Telegex message struct" do
    message = message(from: %User{id: 12_345, first_name: "测试用户", is_bot: false})

    assert HandleAutomationMessageChain.sender_id(message) == 12_345
  end

  test "returns nil when Telegram omits the sender" do
    assert HandleAutomationMessageChain.sender_id(message(from: nil)) == nil
  end

  defp message(options) do
    %Message{
      chat: %Chat{id: -100, type: "supergroup"},
      date: 0,
      message_id: 1,
      from: Keyword.fetch!(options, :from)
    }
  end
end
