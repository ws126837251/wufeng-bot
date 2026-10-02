defmodule PolicrMini.Automation.MessageTemplatesTest do
  use ExUnit.Case, async: true

  alias PolicrMini.Automation.MessageTemplates
  alias PolicrMini.Automation.ChatSetting

  test "merges custom templates over defaults" do
    merged = MessageTemplates.merged(%{"verification_success" => "完成"})

    assert merged["verification_success"] == "完成"
    assert merged["lottery_join_success"] =~ "{count}"
  end

  test "renders placeholders while escaping static Markdown text" do
    text =
      MessageTemplates.render_template(
        "欢迎 {mention}，请在 {seconds} 秒内验证。",
        %{mention: "[小明](tg://user?id=1)", seconds: 300},
        "MarkdownV2"
      )

    assert text =~ "[小明](tg://user?id=1)"
    assert text =~ "300"
  end

  test "catalog exposes every current template with populated content" do
    defaults = MessageTemplates.defaults()
    fields = for group <- MessageTemplates.catalog(), field <- group.fields, do: field

    assert length(fields) == map_size(defaults)
    assert MapSet.new(Enum.map(fields, & &1.key)) == MapSet.new(Map.keys(defaults))
    assert Enum.all?(fields, &(String.trim(&1.default_text) != ""))
  end

  test "normalizes camel-case API keys before validating chat settings" do
    changeset =
      ChatSetting.changeset(%ChatSetting{chat_id: 1}, %{
        "message_templates" => %{
          "verificationSuccess" => "验证通过",
          "memberBlacklistCommandUsage" => "/ban 使用说明"
        }
      })

    assert changeset.valid?

    assert Ecto.Changeset.get_change(changeset, :message_templates) == %{
             "verification_success" => "验证通过",
             "member_blacklist_command_usage" => "/ban 使用说明"
           }
  end

  test "still rejects unknown message template keys" do
    changeset =
      ChatSetting.changeset(%ChatSetting{chat_id: 1}, %{
        "message_templates" => %{"unknownTemplate" => "not allowed"}
      })

    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :message_templates)
  end
end
