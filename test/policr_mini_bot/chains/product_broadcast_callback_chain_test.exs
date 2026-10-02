defmodule PolicrMiniBot.ProductBroadcastCallbackChainTest do
  use ExUnit.Case, async: true

  alias PolicrMini.Instances.Chat
  alias PolicrMiniBot.ProductBroadcastCallbackChain

  test "builds one target button for each eligible group" do
    chats = [
      %Chat{id: -100_123, type: :supergroup, title: "无风｜全球SIM卡代购", is_take_over: true},
      %Chat{id: -100_456, type: :supergroup, title: "新品通知群", is_take_over: true}
    ]

    markup = ProductBroadcastCallbackChain.build_picker_markup(chats, -100_789, 456)

    assert [[first], [second]] = markup.inline_keyboard
    assert first.text == "📤 无风｜全球SIM卡代购"
    assert first.callback_data == "broadcast:v1:send:-100789:456:-100123"
    assert second.text == "📤 新品通知群"
    assert second.callback_data == "broadcast:v1:send:-100789:456:-100456"
  end
end
