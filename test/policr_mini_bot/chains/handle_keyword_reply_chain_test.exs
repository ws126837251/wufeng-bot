defmodule PolicrMiniBot.HandleKeywordReplyChainTest do
  use ExUnit.Case, async: true

  alias PolicrMini.Automation
  alias PolicrMiniBot.HandleKeywordReplyChain
  alias Telegex.Type.User

  test "matches text with the configured mode and case handling" do
    rule = %{keywords: ["WuFeng", "白茶"], match_mode: "contains", case_sensitive: false}
    assert Automation.text_matches?(rule, "欢迎使用 wufeng bot")
    assert Automation.text_matches?(rule, "来一杯白茶")
    refute Automation.text_matches?(%{rule | match_mode: "exact"}, "WuFeng Bot")

    assert Automation.longest_matching_keyword(
             %{rule | keywords: ["客服", "联系客服"]},
             "请联系客服"
           ) == "联系客服"
  end

  test "renders member placeholders and button markup" do
    user = %User{
      id: 123,
      is_bot: false,
      first_name: "无风",
      last_name: "测试",
      username: "wufeng"
    }

    text = HandleKeywordReplyChain.render_response("你好 {user} {username} ID:{id}", user)

    markup =
      HandleKeywordReplyChain.build_markup([%{"text" => "官网", "url" => "https://example.com"}])

    assert text == "你好 无风 测试 @wufeng ID:123"
    assert [[button]] = markup.inline_keyboard
    assert button.text == "官网"
    assert button.url == "https://example.com"
  end
end
