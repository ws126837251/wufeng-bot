defmodule PolicrMiniBot.RespStartChain do
  @moduledoc """
  `/start` 命令。

  与其它命令不同，`/start` 命令不需要保证完整的匹配，以 `/start` 开头的**私聊文本消息**都能进入处理函数。这是因为 `/start` 是当前设计中唯一一个需要携带参数的命令。


  ## 仅匹配一下条件
    - 私聊且以 `/start` 开头的文本消息。
  """

  use PolicrMiniBot.Chain, {:command, :start}

  alias PolicrMini.Automation.{Lottery, MessageTemplates}
  alias PolicrMini.Chats
  alias PolicrMini.PrivateRelays
  alias Telegex.Type.{InlineKeyboardButton, InlineKeyboardMarkup, WebAppInfo}

  import PolicrMiniBot.VerificationHelper

  require Logger

  @management_actions [
    [{"🎁 抽奖中心", "/lottery"}, {"📢 定时消息", "/messages?category=schedules"}],
    [{"🛡️ 入群验证", "/security"}, {"🚫 违禁拦截", "/messages?category=moderation"}],
    [{"💬 自动回复", "/messages?category=replies"}, {"🧹 消息设置", "/messages?category=settings"}],
    [{"📝 机器人文案", "/messages?category=templates"}, {"👥 成员管理", "/members"}],
    [{"🔐 权限管理", "/permissions"}, {"❤️ 运行状态", "/dashboard"}],
    [{"🧾 操作记录", "/histories"}]
  ]

  @type captcha_data :: PolicrMiniBot.Captcha.Data.t()
  @type tgerr :: Telegex.Type.error()
  @type tgmsg :: Telegex.Type.Message.t()

  # 重写匹配规则，消息文本以 `/start` 开始的私聊消息即匹配
  @impl true
  def match?(%{text: text, chat: %{type: "private"}}, _context) when text != nil do
    String.starts_with?(text, @command)
  end

  # 其余皆忽略
  @impl true
  def match?(_message, _context), do: false

  # 转发携带参数
  @impl true
  def handle(%{text: <<@command <> " " <> args_text::binary>>} = message, context) do
    args_text = String.trim(args_text)

    args =
      if String.starts_with?(args_text, "relay_") do
        ["relay", String.replace_prefix(args_text, "relay_", "")]
      else
        String.split(args_text, "_")
      end

    handle_args(args, message)

    {:stop, context}
  end

  # 处理空参数
  @impl true
  def handle(%{chat: chat} = _message, context) do
    text = """
    👋 你好，我是 WuFengBot

    一个专为 Telegram 群组打造的群组管理机器人。

    我可以帮助你：
    ‧ 入群验证与新成员管理
    ‧ 广告、违禁词自动拦截
    ‧ 欢迎语、自动回复和定时群消息
    ‧ 机器人消息自动删除
    ‧ 抽奖、关键词报名与主动开奖
    ‧ 为每个群单独保存和管理设置

    群管理员可通过管理面板可视化配置功能。
    把我添加到群组并授予必要的管理权限，即可开始使用。
    """

    markup = management_markup(context)

    context = %{
      context
      | payload: %{
          method: "sendMessage",
          chat_id: chat.id,
          text: text,
          reply_markup: markup,
          disable_web_page_preview: true,
          parse_mode: "HTML"
        }
    }

    {:done, context}
  end

  def handle_args(["manage" | _rest], %{chat: %{id: chat_id}} = message) do
    send_text(chat_id, "⚙️ WuFengBot 管理快捷入口\n\n请先在面板顶部选择需要管理的群组。",
      reply_markup: management_markup(%{bot: Telegex.Instance.bot()}),
      disable_web_page_preview: true,
      logging: true
    )

    message
  end

  def handle_args(["relay", token], %{from: %{id: user_id}, chat: %{id: chat_id}}) do
    case PrivateRelays.accept_invite(token, user_id) do
      {:ok, relay} ->
        Telegex.send_message(chat_id, "✅ 验证成功！\n你发送给机器人的文字、图片和文件，都会转发给客服。\n如需停止转发，请点击下方按钮。",
          reply_markup: relay_control_markup()
        )
        Telegex.send_message(relay.initiator_id, "✅ 有联系人已通过验证。对方之后发给机器人的消息会转给你。")

      {:error, :not_found} ->
        Telegex.send_message(chat_id, "中转邀请不存在或已失效。")

      {:error, :unavailable} ->
        Telegex.send_message(chat_id, "中转邀请已被使用或已关闭。")

      {:error, :self} ->
        Telegex.send_message(chat_id, "不能接受自己创建的中转邀请。")

      {:error, _reason} ->
        Telegex.send_message(chat_id, "开启中转失败，请稍后重试。")
    end
  end

  def handle_args(["relay"], %{from: %{id: user_id}, chat: %{id: chat_id}}) do
    case PrivateRelays.accept_public(user_id) do
      {:ok, _relay} ->
        Telegex.send_message(chat_id, "✅ 验证成功！\n你发送给机器人的文字、图片和文件，都会转发给客服。\n如需停止转发，请点击下方按钮。",
          reply_markup: relay_control_markup()
        )

      {:error, :self} ->
        Telegex.send_message(chat_id, "客服入口已开启。其他联系人可直接点击机器人并开始联系。")

      {:error, :unavailable} ->
        Telegex.send_message(chat_id, "客服当前未开启公开联系入口。")

      {:error, _reason} ->
        Telegex.send_message(chat_id, "开启联系失败，请稍后重试。")
    end
  end

  def handle_args(
        ["invlt", campaign_id_text, inviter_id_text],
        %{from: user, chat: %{id: chat_id}}
      ) do
    with {:ok, campaign_id} <- parse_integer(campaign_id_text),
         {:ok, inviter_id} <- parse_integer(inviter_id_text),
         {:ok, payload} <- Lottery.referral_prompt(campaign_id, inviter_id) do
      if user.id == inviter_id do
        send_text(chat_id, Lottery.referral_message(payload, :inviter),
          reply_markup: Lottery.referral_markup(payload),
          disable_web_page_preview: true,
          logging: true
        )
      else
        case Lottery.register_referral(campaign_id, inviter_id, user) do
          {:ok, _campaign, :created} ->
            send_text(chat_id, Lottery.referral_message(payload, :invitee),
              reply_markup: Lottery.referral_markup(payload),
              disable_web_page_preview: true,
              logging: true
            )

          {:ok, _campaign, :pending} ->
            send_text(
              chat_id,
              MessageTemplates.render(payload.campaign.chat_id, :lottery_referral_pending),
              reply_markup: Lottery.referral_markup(payload),
              disable_web_page_preview: true,
              logging: true
            )

          {:ok, _campaign, :completed} ->
            send_text(chat_id,
              MessageTemplates.render(payload.campaign.chat_id, :lottery_referral_already_completed),
              logging: true
            )

          {:error, :self} ->
            send_text(
              chat_id,
              MessageTemplates.render(payload.campaign.chat_id, :lottery_referral_self),
              logging: true
            )

          {:error, :inviter_not_joined} ->
            send_text(chat_id,
              MessageTemplates.render(payload.campaign.chat_id, :lottery_referral_inviter_not_joined),
              logging: true
            )

          {:error, :referrals_disabled} ->
            send_text(chat_id, MessageTemplates.render(chat_id, :lottery_referral_disabled),
              logging: true
            )

          _reason ->
            send_text(
              chat_id,
              MessageTemplates.render(payload.campaign.chat_id, :lottery_referral_invalid),
              logging: true
            )
        end
      end
    else
      {:error, :inviter_not_joined} ->
        send_text(chat_id, MessageTemplates.render(chat_id, :lottery_referral_inviter_not_joined),
          logging: true
        )

      {:error, :group_link_unavailable} ->
        send_text(
          chat_id,
          MessageTemplates.render(chat_id, :lottery_referral_group_link_unavailable),
          logging: true
        )

      {:error, :referrals_disabled} ->
        send_text(chat_id, MessageTemplates.render(chat_id, :lottery_referral_disabled),
          logging: true
        )

      _reason ->
        send_text(chat_id, MessageTemplates.render(chat_id, :lottery_referral_invalid), logging: true)
    end
  end

  def handle_args(["lottery", "settings"], %{chat: %{id: chat_id}}) do
    send_lottery_panel(chat_id, nil)
  end

  def handle_args(["lottery", target_chat_id], %{chat: %{id: chat_id}}) do
    send_lottery_panel(chat_id, String.to_integer(target_chat_id))
  end

  defp send_lottery_panel(chat_id, target_chat_id) do
    query = if target_chat_id, do: "?chat_id=#{target_chat_id}", else: ""

    markup = %InlineKeyboardMarkup{
      inline_keyboard: [
        [
          %InlineKeyboardButton{
            text: "打开抽奖设置面板",
            web_app: %WebAppInfo{
              url: "#{PolicrMiniWeb.root_url(has_end_slash: false)}/console/v2/lottery#{query}"
            }
          }
        ]
      ]
    }

    text =
      if target_chat_id,
        do: MessageTemplates.render(target_chat_id, :lottery_private_panel_prompt),
        else: "🎁 点击下方按钮进入抽奖中心。"

    send_text(chat_id, text,
      reply_markup: markup,
      logging: true
    )
  end

  # 处理 v1 版本的验证参数
  def handle_args(["verification", "v1", target_chat_id], %{chat: %{id: from_user_id}} = _message) do
    target_chat_id = String.to_integer(target_chat_id)

    if v = Chats.find_pending_verification(target_chat_id, from_user_id) do
      scheme = Chats.find_or_init_scheme!(target_chat_id)

      case send_verification(v, scheme) do
        {:ok, _} ->
          :ok

        {:error, :too_many_send_times} ->
          send_text(from_user_id, commands_text("同一个验证的发送次数过多，请使用旧消息完成验证。"), logging: true)

        {:error, %{error_code: 403}} = e ->
          Logger.warning(
            "Verification failed to send due to user blocking: #{inspect(user_id: from_user_id)}",
            chat_id: target_chat_id
          )

          e

        {:error, reason} = e ->
          Logger.error(
            "Send verification failed: #{inspect(user_id: from_user_id, reason: reason)}",
            chat_id: target_chat_id
          )

          send_text(from_user_id, commands_text("发生了一些未预料的情况，请向开发者反馈。"), logging: true)

          e
      end
    else
      send_text(from_user_id, commands_text("您没有该目标群组的待验证记录。"), logging: true)
    end
  end

  # 响应未知参数
  def handle_args(_, message) do
    %{chat: %{id: chat_id}} = message

    send_text(chat_id, commands_text("很抱歉，我未能理解您的意图。"), logging: true)
  end

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> {:ok, number}
      _ -> {:error, :invalid_integer}
    end
  end

  defp parse_integer(_value), do: {:error, :invalid_integer}

  @doc false
  def management_markup(context) do
    base_url = "#{PolicrMiniWeb.root_url(has_end_slash: false)}/console/v2"

    action_rows =
      Enum.map(@management_actions, fn row ->
        Enum.map(row, fn {text, path} -> web_button(text, base_url <> path) end)
      end)

    %InlineKeyboardMarkup{
      inline_keyboard:
        action_rows ++
          [
            [
              %InlineKeyboardButton{
                text: "📨 联系客服（无法私聊请点击）",
                url: "https://t.me/#{context.bot.username}?start=relay"
              }
            ],
            [
              %InlineKeyboardButton{
                text: "➕ 添加到群聊",
                url: "https://t.me/#{context.bot.username}?startgroup=added"
              }
            ]
          ]
    }
  end

  defp web_button(text, url) do
    %InlineKeyboardButton{text: text, web_app: %WebAppInfo{url: url}}
  end

  defp relay_control_markup do
    %InlineKeyboardMarkup{
      inline_keyboard: [
        [
          %InlineKeyboardButton{
            text: "▶️ 继续转发",
            callback_data: "relay:v1:resume"
          },
          %InlineKeyboardButton{
            text: "⛔ 停止转发",
            callback_data: "relay:v1:stop"
          }
        ]
      ]
    }
  end
end
