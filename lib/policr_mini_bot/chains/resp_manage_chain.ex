defmodule PolicrMiniBot.RespManageChain do
  @moduledoc "群内打开私聊管理快捷页的命令。"

  use PolicrMiniBot.Chain, {:command, :manage}

  alias PolicrMini.Automation.MessageTemplates
  alias Telegex.Type.{InlineKeyboardButton, InlineKeyboardMarkup}

  @group_types ["group", "supergroup"]

  @impl true
  def handle(
        %{chat: %{id: chat_id, type: type}, message_id: message_id},
        %{from_admin: true} = context
      )
      when type in @group_types do
    markup = %InlineKeyboardMarkup{
      inline_keyboard: [
        [
          %InlineKeyboardButton{
            text: "⚙️ 在机器人私聊中打开",
            url: "https://t.me/#{context.bot.username}?start=manage_#{chat_id}"
          }
        ]
      ]
    }

    send_text(chat_id, MessageTemplates.render(chat_id, :manage_prompt),
      reply_to_message_id: message_id,
      reply_markup: markup,
      auto_delete_after: 60,
      logging: true
    )

    async_delete_message(chat_id, message_id)
    {:stop, %{context | deleted: true}}
  end

  def handle(%{chat: %{id: chat_id}, message_id: message_id}, context) do
    send_text(chat_id, MessageTemplates.render(chat_id, :manage_admin_only),
      reply_to_message_id: message_id,
      auto_delete_after: 8,
      logging: true
    )

    async_delete_message(chat_id, message_id)
    {:stop, %{context | deleted: true}}
  end
end
