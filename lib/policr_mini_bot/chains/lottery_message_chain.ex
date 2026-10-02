defmodule PolicrMiniBot.HandleLotteryMessageChain do
  @moduledoc "处理群内直接发送或回复抽奖关键词的报名消息。"

  use PolicrMiniBot.Chain, :message

  alias PolicrMini.Automation
  alias PolicrMini.Automation.{Lottery, MessageTemplates}

  @impl true
  def match?(
        %{chat: %{type: type}, from: %{id: user_id}, text: text},
        %{from_self: false}
      )
      when type in ["group", "supergroup"] and is_integer(user_id) and is_binary(text),
      do: true

  def match?(_message, _context), do: false

  @impl true
  def handle(
        %{chat: %{id: chat_id}, message_id: message_id, from: user, text: text} = message,
        context
      ) do
    replied_message_id = replied_message_id(message)

    case Lottery.join_by_keyword(chat_id, replied_message_id, user, text) do
      {:ok, count, true, delete_after_seconds} ->
        schedule_entry_message_delete(chat_id, message_id, delete_after_seconds)
        _ = Lottery.send_referral_prompt_for_keyword(chat_id, replied_message_id, user, text)

        send_notice(
          chat_id,
          message_id,
          MessageTemplates.render(chat_id, :lottery_join_success, %{count: count})
        )

      {:ok, _count, false, delete_after_seconds} ->
        schedule_entry_message_delete(chat_id, message_id, delete_after_seconds)

        send_notice(
          chat_id,
          message_id,
          MessageTemplates.render(chat_id, :lottery_join_duplicate)
        )

      {:error, :keyword_mismatch, keyword} ->
        send_notice(
          chat_id,
          message_id,
          MessageTemplates.render(chat_id, :lottery_keyword_mismatch, %{keyword: keyword})
        )

      {:error, :ambiguous_keyword} ->
        send_notice(
          chat_id,
          message_id,
          MessageTemplates.render(chat_id, :lottery_keyword_ambiguous)
        )

      _ ->
        :ok
    end

    {:ok, context}
  end

  defp replied_message_id(%{reply_to_message: %{message_id: message_id}})
       when is_integer(message_id),
       do: message_id

  defp replied_message_id(_message), do: nil

  defp send_notice(chat_id, reply_to_message_id, text) do
    case send_text(chat_id, text,
           reply_to_message_id: reply_to_message_id,
           disable_notification: true,
           logging: true
         ) do
      {:ok, %{message_id: message_id}} -> async_delete_message_after(chat_id, message_id, 8)
      _ -> :ok
    end
  end

  defp schedule_entry_message_delete(_chat_id, _message_id, nil), do: :ok

  defp schedule_entry_message_delete(chat_id, message_id, seconds) do
    Automation.schedule_delete(chat_id, message_id, seconds, "lottery_entry")
    :ok
  end
end
