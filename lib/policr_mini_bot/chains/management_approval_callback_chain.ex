defmodule PolicrMiniBot.ManagementApprovalCallbackChain do
  @moduledoc false

  use PolicrMiniBot.Chain, {:callback_query, prefix: "approval:"}

  alias PolicrMini.ManagementApprovals
  alias Telegex.Type.InlineKeyboardMarkup

  @impl true
  def handle(%{data: data, from: %{id: owner_user_id}} = callback_query, context) do
    result =
      case parse_callback_data(data) do
        {"v1", ["a", id, token]} -> approve(callback_query, id, token, owner_user_id)
        {"v1", ["r", id, token]} -> reject(callback_query, id, token, owner_user_id)
        _ -> invalid(callback_query)
      end

    case result do
      :ok -> {:stop, context}
      _ -> {:stop, context}
    end
  end

  defp approve(callback_query, id, token, owner_user_id) do
    with {approval_id, ""} <- Integer.parse(id),
         {:ok, approval, _result} <-
           ManagementApprovals.approve(approval_id, token, owner_user_id) do
      update_notification(callback_query, ManagementApprovals.notification_result_text(approval, :approved))
      Telegex.answer_callback_query(callback_query.id, text: "已同意，操作执行成功。", show_alert: true)
      :ok
    else
      {:error, {:already_decided, status}} -> already_decided(callback_query, status)
      {:error, :not_owner} -> denied(callback_query)
      {:error, reason} -> failed(callback_query, parse_id(id), reason)
      _ -> invalid(callback_query)
    end
  end

  defp reject(callback_query, id, token, owner_user_id) do
    with {approval_id, ""} <- Integer.parse(id),
         {:ok, approval} <- ManagementApprovals.reject(approval_id, token, owner_user_id) do
      update_notification(callback_query, ManagementApprovals.notification_result_text(approval, :rejected))
      Telegex.answer_callback_query(callback_query.id, text: "已拒绝，该操作不会执行。", show_alert: true)
      :ok
    else
      {:error, {:already_decided, status}} -> already_decided(callback_query, status)
      {:error, :not_owner} -> denied(callback_query)
      {:error, reason} -> failed(callback_query, parse_id(id), reason)
      _ -> invalid(callback_query)
    end
  end

  defp update_notification(%{message: %{chat: %{id: chat_id}, message_id: message_id}}, text) do
    Telegex.edit_message_text(text,
      chat_id: chat_id,
      message_id: message_id,
      parse_mode: "HTML",
      reply_markup: %InlineKeyboardMarkup{inline_keyboard: []}
    )
  end

  defp already_decided(callback_query, status) do
    Telegex.answer_callback_query(callback_query.id,
      text: "该申请已经处理（#{status}）。",
      show_alert: true
    )
  end

  defp denied(callback_query) do
    Telegex.answer_callback_query(callback_query.id, text: "只有当前群主可以审批。", show_alert: true)
  end

  defp failed(callback_query, approval_id, reason) do
    case ManagementApprovals.get(approval_id) do
      nil -> :ok
      approval ->
        update_notification(
          callback_query,
          ManagementApprovals.notification_result_text(approval, {:failed, reason})
        )
    end

    Telegex.answer_callback_query(callback_query.id,
      text: "执行失败：#{inspect(reason, limit: 5)}",
      show_alert: true
    )
  end

  defp invalid(callback_query) do
    Telegex.answer_callback_query(callback_query.id, text: "审批按钮无效。", show_alert: true)
  end

  defp parse_id(id) do
    case Integer.parse(id) do
      {value, ""} -> value
      _ -> nil
    end
  end
end
