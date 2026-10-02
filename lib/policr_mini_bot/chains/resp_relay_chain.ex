defmodule PolicrMiniBot.RespRelayChain do
  @moduledoc false

  use PolicrMiniBot.Chain, {:command, :relay}

  alias PolicrMini.PrivateRelays
  alias Telegex.Type.{InlineKeyboardButton, InlineKeyboardMarkup}

  @impl true
  def match?(%{chat: %{type: "private"}, text: text}, _context) when is_binary(text),
    do: String.starts_with?(text, @command)
  def match?(_message, _context), do: false

  @impl true
  def handle(%{text: text, from: %{id: user_id}, chat: %{id: chat_id}}, context) do
    case String.split(text || "", ~r/\s+/, trim: true) do
      ["/relay", "stop"] ->
        if user_id == PolicrMiniBot.config_get(:owner_id) do
          PrivateRelays.disable_public(user_id)
          PrivateRelays.close_for(user_id)
          Telegex.send_message(chat_id, "已关闭公开中转入口，所有访客的中转也已停止。")
        else
          PrivateRelays.close_for(user_id)
          Telegex.send_message(chat_id, "已关闭你与客服之间的消息中转。")
        end

      ["/relay"] ->
        if user_id == PolicrMiniBot.config_get(:owner_id) do
          case PrivateRelays.enable_public(user_id) do
            {:ok, _gateway} ->
              link = "https://t.me/#{PolicrMiniBot.username()}?start=relay"

              Telegex.send_message(chat_id, "公开联系入口已开启。B、C、D 等联系人无需等你在线，直接搜索机器人或点击这条链接，验证后就能给你留言：\n\n#{link}\n\n使用 /relay stop 可关闭入口并断开全部联系人。")

            {:error, _reason} ->
              Telegex.send_message(chat_id, "开启公开联系入口失败，请稍后重试。")
          end
        else
          case PrivateRelays.accept_public(user_id) do
            {:ok, _relay} ->
              Telegex.send_message(chat_id, "✅ 验证成功！\n你发送给机器人的文字、图片和文件，都会转发给客服。\n如需停止转发，请点击下方按钮。",
                reply_markup: relay_control_markup()
              )

            {:error, :unavailable} ->
              Telegex.send_message(chat_id, "客服当前未开启公开联系入口。")

            {:error, _reason} ->
              Telegex.send_message(chat_id, "开启联系失败，请稍后重试。")
          end
        end

      _ ->
        Telegex.send_message(chat_id, "用法：直接发送 /relay 验证并联系客服；发送 /relay stop 可退出转发。")
    end

    {:stop, context}
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
