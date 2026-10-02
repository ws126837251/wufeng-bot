defmodule PolicrMiniBot.RelayCallbackChain do
  @moduledoc false

  use PolicrMiniBot.Chain, {:callback_query, prefix: "relay:"}

  @impl true
  def handle(%{data: data, from: %{id: user_id}} = callback_query, context) do
    case parse_callback_data(data) do
      {"v1", ["resume"]} ->
        case PolicrMini.PrivateRelays.accept_public(user_id) do
          {:ok, _relay} ->
            Telegex.answer_callback_query(callback_query.id, text: "已恢复转发。")
            Telegex.send_message(user_id, "已恢复转发。")

          {:error, :unavailable} ->
            Telegex.answer_callback_query(callback_query.id, text: "客服当前未开启公开联系入口。", show_alert: true)

          {:error, :self} ->
            Telegex.answer_callback_query(callback_query.id, text: "客服无需恢复转发。", show_alert: true)

          {:error, _reason} ->
            Telegex.answer_callback_query(callback_query.id, text: "恢复转发失败，请稍后重试。", show_alert: true)
        end

      {"v1", ["stop"]} ->
        PolicrMini.PrivateRelays.close_for(user_id)
        Telegex.answer_callback_query(callback_query.id, text: "已停止转发。")
        Telegex.send_message(user_id, "已停止转发。")

      _ ->
        Telegex.answer_callback_query(callback_query.id, text: "停止按钮已失效，请重新验证。", show_alert: true)
    end

    {:stop, context}
  end
end
