defmodule PolicrMiniBot.RespLotteryDrawChain do
  @moduledoc "群内主动开奖命令。"

  use PolicrMiniBot.Chain, {:command, :draw}

  alias PolicrMini.Automation.{Lottery, MessageTemplates}
  alias PolicrMini.ManagementApprovals

  require Logger

  @group_types ["group", "supergroup"]

  @impl true
  def handle(
        %{chat: %{id: chat_id, type: type}, message_id: message_id},
        %{from_admin: true} = context
      )
      when type in @group_types do
    case Lottery.latest_active(chat_id) do
      %{id: campaign_id, title: title} ->
        path = "/console/v2/api/chats/#{chat_id}/lotteries/#{campaign_id}/draw"

        case ManagementApprovals.request_action(
               chat_id,
               context.user_id,
               "POST",
               path,
               %{},
               "LotteryController.draw",
               "立即开奖｜lottery_id=#{campaign_id}，title=#{title}"
             ) do
          {:ok, _approval} ->
            reply_and_cleanup(
              chat_id,
              message_id,
              MessageTemplates.render(chat_id, :management_approval_submitted),
              context
            )

          {:error, :owner_private_chat_unavailable} ->
            reply_and_cleanup(
              chat_id,
              message_id,
              MessageTemplates.render(chat_id, :management_approval_owner_unavailable),
              context
            )

          {:error, reason} ->
            Logger.warning("Lottery draw approval request failed: #{inspect(reason)}", chat_id: chat_id)

            reply_and_cleanup(
              chat_id,
              message_id,
              MessageTemplates.render(chat_id, :lottery_draw_failed),
              context
            )
        end

      nil ->
        reply_and_cleanup(
          chat_id,
          message_id,
          MessageTemplates.render(chat_id, :lottery_draw_none),
          context
        )

    end
  end

  def handle(%{chat: %{id: chat_id}, message_id: message_id}, context) do
    reply_and_cleanup(
      chat_id,
      message_id,
      MessageTemplates.render(chat_id, :lottery_draw_admin_only),
      context
    )
  end

  defp reply_and_cleanup(chat_id, message_id, text, context) do
    send_text(chat_id, text,
      reply_to_message_id: message_id,
      auto_delete_after: 8,
      logging: true
    )

    async_delete_message(chat_id, message_id)
    {:stop, %{context | deleted: true}}
  end
end
