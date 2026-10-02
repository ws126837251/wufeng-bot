defmodule PolicrMiniBot.LotteryCallbackChain do
  @moduledoc "处理群内抽奖报名按钮。"

  use PolicrMiniBot.Chain, {:callback_query, prefix: "lottery:"}

  alias PolicrMini.Automation.{Lottery, MessageTemplates}

  @impl true
  def handle(%{data: data, from: user, message: %{chat: chat}} = callback_query, context) do
    case data |> parse_callback_data() do
      {"v1", ["join", campaign_id]} ->
        handle_join(callback_query, chat.id, user, String.to_integer(campaign_id))

      {"v1", ["invite", campaign_id]} ->
        handle_invite(callback_query, chat.id, String.to_integer(campaign_id), user.id)

      _ ->
        answer(callback_query.id, chat.id, :lottery_button_invalid, show_alert: true)
    end

    {:stop, context}
  end

  defp handle_join(callback_query, chat_id, user, campaign_id) do
    case Lottery.join_for_chat(chat_id, campaign_id, user) do
      {:ok, _count, true} ->
        answer(callback_query.id, chat_id, :lottery_button_joined)
        Lottery.refresh_message(campaign_id)
        _ = Lottery.send_referral_prompt(campaign_id, user)

      {:ok, _count, false} ->
        answer(callback_query.id, chat_id, :lottery_button_duplicate)

      {:error, :closed} ->
        answer(callback_query.id, chat_id, :lottery_button_closed, show_alert: true)

      {:error, :not_found} ->
        answer(callback_query.id, chat_id, :lottery_button_not_found, show_alert: true)

      {:error, reason} ->
        answer(callback_query.id, chat_id, :lottery_button_failed, show_alert: true)
        require Logger
        Logger.warning("Lottery join failed: #{inspect(reason)}", chat_id: chat_id)
    end
  end

  defp handle_invite(callback_query, chat_id, campaign_id, user_id) do
    case Lottery.referral_prompt(campaign_id, user_id) do
      {:ok, payload} ->
        Telegex.answer_callback_query(
          callback_query.id,
          text: MessageTemplates.render(chat_id, :lottery_button_invite_sent),
          url: payload.link
        )

      {:error, :inviter_not_joined} ->
        answer(callback_query.id, chat_id, :lottery_referral_inviter_not_joined, show_alert: true)

      {:error, :group_link_unavailable} ->
        answer(
          callback_query.id,
          chat_id,
          :lottery_referral_group_link_unavailable,
          show_alert: true
        )

      {:error, :referrals_disabled} ->
        answer(callback_query.id, chat_id, :lottery_referral_disabled, show_alert: true)

      _ ->
        answer(callback_query.id, chat_id, :lottery_button_invite_invalid, show_alert: true)
    end
  end

  defp answer(callback_query_id, chat_id, key, opts \\ []) do
    Telegex.answer_callback_query(
      callback_query_id,
      Keyword.merge([text: MessageTemplates.render(chat_id, key)], opts)
    )
  end
end
