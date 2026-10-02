defmodule PolicrMiniBot.VerificationHelperTest do
  use ExUnit.Case, async: true

  alias PolicrMini.Automation.MessageTemplates

  test "mentions the new member in a single-user verification entry" do
    text =
      MessageTemplates.render_template(
        MessageTemplates.defaults()["verification_entry_single"],
        %{mention: "[小明](tg://user?id=123)", seconds: 300},
        "MarkdownV2"
      )

    assert text =~ "[小明](tg://user?id=123)"
    assert text =~ "欢迎"
    assert text =~ "验证有效时间不超过 300 秒"
  end

  test "mentions the latest member and reports the remaining count" do
    text =
      MessageTemplates.render_template(
        MessageTemplates.defaults()["verification_entry_multiple"],
        %{mention: "[小红](tg://user?id=456)", remaining_count: 2, seconds: 180},
        "MarkdownV2"
      )

    assert text =~ "[小红](tg://user?id=456)"
    assert text =~ "另外 2 位新成员"
  end
end
