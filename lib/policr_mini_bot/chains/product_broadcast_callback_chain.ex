defmodule PolicrMiniBot.ProductBroadcastCallbackChain do
  @moduledoc false

  use PolicrMiniBot.Chain, {:callback_query, prefix: "broadcast:"}

  alias PolicrMini.Accounts
  alias PolicrMini.Instances
  alias PolicrMini.Instances.Chat
  alias Telegex.Type.{InlineKeyboardButton, InlineKeyboardMarkup}

  @target_chat_types [:group, :supergroup, :channel, "group", "supergroup", "channel"]

  @impl true
  def handle(%{data: data} = callback_query, context) do
    case parse_callback_data(data) do
      {"v1", ["open"]} -> open_picker(callback_query)
      {"v1", ["send", source_chat_id, source_message_id, target_chat_id]} ->
        send_to_chat(callback_query, source_chat_id, source_message_id, target_chat_id)

      _ -> answer(callback_query, "发送按钮已失效，请重新打开新品通知。", true)
    end

    {:stop, context}
  end

  @doc false
  @spec build_picker_markup([Chat.t()], integer(), integer()) :: InlineKeyboardMarkup.t()
  def build_picker_markup(chats, source_chat_id, source_message_id) do
    rows =
      Enum.map(chats, fn chat ->
        [
          %InlineKeyboardButton{
            text: "📤 " <> display_title(chat),
            callback_data: "broadcast:v1:send:#{source_chat_id}:#{source_message_id}:#{chat.id}"
          }
        ]
      end)

    %InlineKeyboardMarkup{inline_keyboard: rows}
  end

  defp open_picker(
         %{
           from: %{id: user_id},
           message: %{chat: %{id: source_chat_id}, message_id: source_message_id}
         } = callback_query
       ) do
    with {:ok, user} <- current_user(user_id),
         [_ | _] = chats <- eligible_chats(user),
         {:ok, _message} <-
           Telegex.send_message(user_id, "请选择要发送新品通知的群组：",
             reply_markup: build_picker_markup(chats, source_chat_id, source_message_id)
           ) do
      answer(callback_query, "已在与机器人的私聊中打开群组选择。")
    else
      [] -> answer(callback_query, "没有可发送的已管理群组。", true)
      :not_found -> answer(callback_query, "没有可发送的已管理群组。", true)
      {:error, reason} -> answer(callback_query, "群组列表打开失败：#{telegram_error(reason)}", true)
    end
  end

  defp send_to_chat(
         %{from: %{id: user_id}} = callback_query,
         source_chat_id,
         source_message_id,
         target_chat_id
       ) do
    with {:ok, source_chat_id} <- parse_integer(source_chat_id),
         {:ok, source_message_id} <- parse_positive_integer(source_message_id),
         {:ok, target_chat_id} <- parse_integer(target_chat_id),
         {:ok, user} <- current_user(user_id),
         %Chat{} = chat <- eligible_chat(user, target_chat_id),
         {:ok, _message_id} <-
           Telegex.copy_message(chat.id, source_chat_id, source_message_id, disable_notification: true) do
      answer(callback_query, "已发送到 #{display_title(chat)}。")
    else
      :not_found -> answer(callback_query, "该群组已无发送权限，请重新选择。", true)
      :invalid -> answer(callback_query, "发送参数已失效，请重新打开新品通知。", true)
      {:error, reason} -> answer(callback_query, "发送失败：#{telegram_error(reason)}", true)
    end
  end

  defp current_user(user_id) do
    case Accounts.get_user(user_id) do
      nil -> :not_found
      user -> {:ok, user}
    end
  end

  defp eligible_chats(user) do
    user.id
    |> Instances.find_user_chats()
    |> Enum.filter(&(&1.type in @target_chat_types))
  end

  defp eligible_chat(user, chat_id) do
    Enum.find(eligible_chats(user), :not_found, &(&1.id == chat_id))
  end

  defp parse_positive_integer(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> {:ok, integer}
      _ -> :invalid
    end
  end

  defp parse_integer(value) do
    case Integer.parse(value) do
      {integer, ""} -> {:ok, integer}
      _ -> :invalid
    end
  end

  defp display_title(%Chat{title: title}) do
    (title || "")
    |> to_string()
    |> String.trim()
    |> case do
      "" -> "未命名群组"
      value -> String.slice(value, 0, 48)
    end
  end

  defp answer(callback_query, text, show_alert \\ false) do
    Telegex.answer_callback_query(callback_query.id, text: text, show_alert: show_alert)
  end

  defp telegram_error(reason), do: inspect(reason, limit: 4)
end
