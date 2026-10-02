defmodule PolicrMiniBot.RespLotteryActiveChain do
  @moduledoc "群内查看正在进行的抽奖。"

  use PolicrMiniBot.Chain, {:command, :active}

  alias PolicrMini.Automation.{Lottery, MessageTemplates}

  @group_types ["group", "supergroup"]

  @impl true
  def handle(%{chat: %{id: chat_id, type: type}, message_id: message_id}, context)
      when type in @group_types do
    campaigns = Lottery.list(chat_id) |> Enum.filter(&(&1.status == "active"))

    text =
      case campaigns do
        [] -> MessageTemplates.render(chat_id, :active_lottery_none)
        campaigns -> render_campaigns(chat_id, campaigns)
      end

    send_text(chat_id, text,
      reply_to_message_id: message_id,
      auto_delete_after: 60,
      logging: true
    )

    async_delete_message(chat_id, message_id)
    {:stop, %{context | deleted: true}}
  end

  def handle(_message, context), do: {:stop, context}

  defp render_campaigns(chat_id, campaigns) do
    header = MessageTemplates.render(chat_id, :active_lottery_header, %{count: length(campaigns)})

    items =
      campaigns
      |> Enum.take(10)
      |> Enum.map_join("\n\n", fn campaign ->
        entry_method =
          if is_binary(campaign.entry_keyword) and String.trim(campaign.entry_keyword) != "",
            do: "发送或回复“#{campaign.entry_keyword}”",
            else: "点击立即参加按钮"

        MessageTemplates.render(chat_id, :active_lottery_item, %{
          title: campaign.title,
          prize: campaign.prize,
          participants: campaign.participant_count,
          end_at: Calendar.strftime(campaign.end_at, "%Y-%m-%d %H:%M UTC"),
          entry_method: entry_method
        })
      end)

    header <> "\n\n" <> items
  end
end
