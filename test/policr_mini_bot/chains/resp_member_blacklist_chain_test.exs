defmodule PolicrMiniBot.RespMemberBlacklistChainTest do
  use ExUnit.Case, async: true

  alias PolicrMiniBot.RespMemberBlacklistChain

  test "matches the plain command and this bot mention only" do
    assert RespMemberBlacklistChain.command_token?("/ban", "wufengde_bot")
    assert RespMemberBlacklistChain.command_token?("/ban@WuFengDe_Bot", "wufengde_bot")
    refute RespMemberBlacklistChain.command_token?("/ban@other_bot", "wufengde_bot")
    refute RespMemberBlacklistChain.command_token?("/banner", "wufengde_bot")

    assert RespMemberBlacklistChain.command_target_token?("/ban@Evan", "wufengde_bot")
    refute RespMemberBlacklistChain.command_target_token?("/ban@WuFengDe_Bot", "wufengde_bot")

    assert RespMemberBlacklistChain.match?(
             %{text: "/ban@Evan", chat: %{type: "supergroup"}},
             %{bot: %{username: "wufengde_bot"}}
           )
  end

  test "parses username, numeric id and optional reason" do
    assert RespMemberBlacklistChain.parse_request(%{text: "/ban @member_name 重复发布广告"}) ==
             {:ok, "@member_name", "重复发布广告"}

    assert RespMemberBlacklistChain.parse_request(%{text: "/ban 123456"}) ==
             {:ok, "123456", ""}

    assert RespMemberBlacklistChain.parse_request(
             %{text: "/ban@Evan 重复发布广告"},
             "wufengde_bot"
           ) == {:ok, "@Evan", "重复发布广告"}

    assert RespMemberBlacklistChain.parse_request(
             %{text: "/ban@wufengde_bot @member_name 刷屏"},
             "wufengde_bot"
           ) == {:ok, "@member_name", "刷屏"}
  end

  test "uses the exact Telegram user selected in a text mention" do
    message = %{
      text: "/ban@Evan 恶意刷屏",
      entities: [
        %{type: "bot_command", offset: 0, length: 4},
        %{type: "text_mention", offset: 4, length: 5, user: %{id: 607_548_3796}}
      ]
    }

    assert RespMemberBlacklistChain.parse_request(message, "wufengde_bot") ==
             {:ok, "6075483796", "恶意刷屏"}
  end

  test "handles UTF-16 offsets for selected members with non-ASCII names" do
    message = %{
      text: "/ban张三 发布广告",
      entities: [
        %{type: "bot_command", offset: 0, length: 4},
        %{type: "text_mention", offset: 4, length: 2, user: %{id: 998_877}}
      ]
    }

    assert RespMemberBlacklistChain.parse_request(message, "wufengde_bot") ==
             {:ok, "998877", "发布广告"}
  end

  test "uses the replied member when no explicit target is present" do
    message = %{
      text: "/ban 恶意刷屏",
      reply_to_message: %{from: %{id: 998_877}}
    }

    assert RespMemberBlacklistChain.parse_request(message) ==
             {:ok, "998877", "恶意刷屏"}
  end

  test "requires a target and limits the reason length" do
    assert RespMemberBlacklistChain.parse_request(%{text: "/ban"}) == {:error, :usage}

    assert RespMemberBlacklistChain.parse_request(%{
             text: "/ban @member_name #{String.duplicate("a", 201)}"
           }) == {:error, :reason_too_long}
  end

  test "executes owner commands directly and keeps administrator approval" do
    assert RespMemberBlacklistChain.execution_mode(%{from_owner: true}) == :direct
    assert RespMemberBlacklistChain.execution_mode(%{from_owner: false}) == :approval
  end
end
