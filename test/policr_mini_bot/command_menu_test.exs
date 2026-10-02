defmodule PolicrMiniBot.CommandMenuTest do
  use ExUnit.Case, async: true

  alias PolicrMiniBot.{BootHelper, RespStartChain, RespStatusChain}

  test "private and group command menus stay separated" do
    assert BootHelper.command_menu().private == [{"start", "打开 WuFengBot"}]

    assert Enum.map(BootHelper.command_menu().group, &elem(&1, 0)) ==
             ~w(lottery draw active ban manage status)
  end

  test "private management page contains eleven distinct functional buttons" do
    markup = RespStartChain.management_markup(%{bot: %{username: "wufengde_bot"}})

    management_buttons = markup.inline_keyboard |> Enum.take(6) |> List.flatten()

    assert Enum.map(management_buttons, & &1.text) == [
             "🎁 抽奖中心",
             "📢 定时消息",
             "🛡️ 入群验证",
             "🚫 违禁拦截",
             "💬 自动回复",
             "🧹 消息设置",
             "📝 机器人文案",
             "👥 成员管理",
             "🔐 权限管理",
             "❤️ 运行状态",
             "🧾 操作记录"
           ]

    urls = Enum.map(management_buttons, & &1.web_app.url)

    assert Enum.uniq(urls) == urls

    assert Enum.map(
             urls,
             &String.replace_prefix(&1, PolicrMiniWeb.root_url(has_end_slash: false), "")
           ) == [
             "/console/v2/lottery",
             "/console/v2/messages?category=schedules",
             "/console/v2/security",
             "/console/v2/messages?category=moderation",
             "/console/v2/messages?category=replies",
             "/console/v2/messages?category=settings",
             "/console/v2/messages?category=templates",
             "/console/v2/members",
             "/console/v2/permissions",
             "/console/v2/dashboard",
             "/console/v2/histories"
           ]
  end

  test "status text reports all required Telegram permissions" do
    health = %{
      status: "healthy",
      takeover: true,
      permissions: %{
        administrator: true,
        send_messages: true,
        delete_messages: true,
        restrict_members: true,
        pin_messages: false
      }
    }

    text = RespStatusChain.status_text(health)

    assert text =~ "服务状态：正常 ✅"
    assert text =~ "删除消息：正常 ✅"
    assert text =~ "置顶消息：缺失 ❌"
  end
end
