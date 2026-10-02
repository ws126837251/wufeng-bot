defmodule PolicrMiniBot.HandleAutomationMessageChain do
  @moduledoc """
  Deletes group messages that match a configured forbidden word.

  Telegram privacy mode must be disabled and the bot needs delete permission.
  """

  use PolicrMiniBot.Chain, :message

  alias PolicrMini.Automation

  @impl true
  def match?(%{chat: %{type: type}}, %{taken_over: true, from_self: false, from_admin: false})
      when type in ["group", "supergroup"] do
    true
  end

  def match?(_message, _context), do: false

  @impl true
  def handle(%{chat: %{id: chat_id}, message_id: message_id} = message, context) do
    if exempt_sender?(message) do
      {:ok, context}
    else
      moderate_message(message, context, chat_id, message_id)
    end
  end

  defp moderate_message(message, context, chat_id, message_id) do
    text = Map.get(message, :text) || Map.get(message, :caption) || ""
    user_id = sender_id(message)

    case Automation.find_forbidden_word(chat_id, text) do
      nil ->
        {:ok, context}

      rule ->
        {delete_status, delete_details} =
          telegram_result(Telegex.delete_message(chat_id, message_id))

        action = Automation.resolve_moderation_action(chat_id, user_id, rule)
        {action_status, action_details} = apply_action(chat_id, user_id, action)

        status =
          if delete_status == "applied" and action_status in ["applied", "skipped"],
            do: action_status,
            else: "failed"

        Automation.create_moderation_event(chat_id, %{
          "message_id" => message_id,
          "user_id" => user_id,
          "rule_id" => rule.id,
          "rule_word" => rule.word,
          "action" => action,
          "status" => status,
          "details" => %{
            "delete" => Map.put(delete_details, "status", delete_status),
            "action" => Map.put(action_details, "status", action_status)
          }
        })

        send_warning(chat_id, rule)
        {:ok, %{context | done: true, deleted: true}}
    end
  end

  @doc false
  def sender_id(%{from: %{id: id}}) when is_integer(id), do: id
  def sender_id(_message), do: nil

  defp exempt_sender?(%{from: %{is_bot: true}}), do: true
  defp exempt_sender?(message), do: Map.get(message, :sender_chat) != nil

  defp send_warning(chat_id, rule) do
    setting = Automation.get_settings!(chat_id)
    text = rule.warning_text || setting.forbidden_warning_text

    if is_binary(text) and String.trim(text) != "" do
      send_text(chat_id, text,
        auto_delete_after: setting.forbidden_warning_delete_after_seconds,
        disable_notification: true
      )
    end
  end

  defp apply_action(_chat_id, nil, "delete_warn"), do: {"applied", %{}}
  defp apply_action(_chat_id, nil, _action), do: {"skipped", %{"reason" => "消息没有可处理的用户信息"}}
  defp apply_action(_chat_id, _user_id, "delete_warn"), do: {"applied", %{}}

  defp apply_action(chat_id, user_id, "mute_10m") do
    telegram_result(restrict_chat_member_until(chat_id, user_id, 600))
  end

  defp apply_action(chat_id, user_id, "mute_1h") do
    telegram_result(restrict_chat_member_until(chat_id, user_id, 3_600))
  end

  defp apply_action(chat_id, user_id, "ban") do
    telegram_result(Telegex.ban_chat_member(chat_id, user_id))
  end

  defp telegram_result({:ok, _}), do: {"applied", %{}}

  defp telegram_result({:error, reason}),
    do: {"failed", %{"reason" => inspect(reason, limit: 12)}}

  defp telegram_result(other), do: {"failed", %{"reason" => inspect(other, limit: 12)}}
end
