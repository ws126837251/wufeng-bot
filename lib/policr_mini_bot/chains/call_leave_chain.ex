defmodule PolicrMiniBot.CallLeaveChain do
  @moduledoc false

  use PolicrMiniBot.Chain, {:callback_query, prefix: "leave:"}

  alias PolicrMini.ManagementApprovals
  alias PolicrMini.Automation.MessageTemplates

  @impl true
  def handle(callback_query, %{from_admin: from_admin} = context)
      when from_admin == nil or from_admin == false do
    Telegex.answer_callback_query(callback_query.id, text: "您没有权限。", show_alert: true)
    {:stop, context}
  end

  @impl true
  def handle(%{data: data} = callback_query, context) do
    data |> parse_callback_data() |> handle_data(callback_query, context)
  end

  defp handle_data({"v1", [chat_id]}, callback_query, context) do
    %{message: %{message_id: message_id}} = callback_query

    case ManagementApprovals.request_action(
           String.to_integer(chat_id),
           context.user_id,
           "POST",
           "/console/v2/api/chats/#{chat_id}/leave",
           %{},
           "ChatController.leave",
           "让 WuFengBot 退出群组"
         ) do
      {:ok, _approval} ->
        Telegex.answer_callback_query(callback_query.id, text: "已提交群主审批。", show_alert: true)

        Telegex.edit_message_text(MessageTemplates.render(String.to_integer(chat_id), :management_approval_submitted),
          chat_id: chat_id,
          message_id: message_id
        )

      {:error, reason} ->
        Telegex.answer_callback_query(callback_query.id,
          text: "提交审批失败：#{inspect(reason, limit: 5)}",
          show_alert: true
        )
    end

    {:stop, context}
  end
end
