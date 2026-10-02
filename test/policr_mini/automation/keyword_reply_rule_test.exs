defmodule PolicrMini.Automation.KeywordReplyRuleTest do
  use ExUnit.Case, async: true

  alias PolicrMini.Automation.KeywordReplyRule

  test "accepts reply text and safe Telegram buttons" do
    changeset =
      KeywordReplyRule.changeset(%KeywordReplyRule{}, %{
        chat_id: -100,
        keywords: [" 官网 ", "客服", "官网"],
        response_text: "点击下面按钮",
        buttons: [
          %{"text" => "打开网站", "url" => "https://bot.wufeng.de"},
          %{"text" => "联系我", "url" => "tg://resolve?domain=wufengde_bot"}
        ]
      })

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :keyword) == "官网"
    assert Ecto.Changeset.get_field(changeset, :keywords) == ["官网", "客服"]
  end

  test "rejects unsafe button URLs" do
    changeset =
      KeywordReplyRule.changeset(%KeywordReplyRule{}, %{
        chat_id: -100,
        keywords: ["官网"],
        response_text: "点击下面按钮",
        buttons: [%{"text" => "危险链接", "url" => "javascript:alert(1)"}]
      })

    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :buttons)
  end

  test "requires at least one keyword" do
    changeset =
      KeywordReplyRule.changeset(%KeywordReplyRule{}, %{
        chat_id: -100,
        keywords: ["", "  "],
        response_text: "没有关键词时不能保存"
      })

    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :keywords)
  end
end
