defmodule PolicrMiniBot.HandleKeywordReplyChain do
  @moduledoc "群成员消息命中自定义关键词后发送文字和跳转按钮。"

  use PolicrMiniBot.Chain, :message

  alias PolicrMini.Automation
  alias Telegex.Type.{InlineKeyboardButton, InlineKeyboardMarkup}

  @impl true
  def match?(%{chat: %{type: type}, from: %{is_bot: false}}, %{taken_over: true, from_self: false})
      when type in ["group", "supergroup"],
      do: true

  def match?(_message, _context), do: false

  @impl true
  def handle(%{chat: %{id: chat_id}, message_id: message_id, from: user} = message, context) do
    text = Map.get(message, :text) || Map.get(message, :caption) || ""

    case Automation.find_keyword_reply(chat_id, text) do
      nil ->
        {:ok, context}

      rule ->
        options = [reply_to_message_id: message_id, logging: true]
        options = with_markup(options, build_markup(rule.buttons))
        send_text(chat_id, render_response(rule.response_text, user), options)
        {:ok, %{context | done: true}}
    end
  end

  @doc false
  def render_response(text, user) do
    username = if is_binary(user.username), do: "@#{user.username}", else: ""

    text
    |> String.replace("{user}", full_name(user))
    |> String.replace("{username}", username)
    |> String.replace("{id}", to_string(user.id))
  end

  @doc false
  def build_markup([]), do: nil

  def build_markup(buttons) when is_list(buttons) do
    rows =
      Enum.map(buttons, fn button ->
        text = Map.get(button, "text", Map.get(button, :text))
        url = Map.get(button, "url", Map.get(button, :url))
        [%InlineKeyboardButton{text: text, url: url}]
      end)

    %InlineKeyboardMarkup{inline_keyboard: rows}
  end

  defp with_markup(options, nil), do: options
  defp with_markup(options, markup), do: Keyword.put(options, :reply_markup, markup)

  defp full_name(user) do
    [user.first_name, user.last_name]
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
    |> Enum.join(" ")
  end
end
