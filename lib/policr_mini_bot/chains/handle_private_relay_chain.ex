defmodule PolicrMiniBot.HandlePrivateRelayChain do
  @moduledoc false

  use PolicrMiniBot.Chain, :message

  alias PolicrMini.PrivateRelays

  @impl true
  def match?(%{chat: %{type: "private"}, text: text}, _context) do
    not is_binary(text) or not String.starts_with?(text, "/")
  end

  def match?(_message, _context), do: false

  @impl true
  def handle(%{chat: %{id: sender_id}, message_id: message_id} = message, context) do
    sender = Map.get(message, :from, %{})

    case PrivateRelays.active_for(sender_id) do
      nil ->
        {:ok, context}

      relay ->
        case PrivateRelays.peer_id(relay, sender_id) do
          peer_id when is_integer(peer_id) ->
            result =
              with {:ok, _notice} <-
                     Telegex.send_message(
                       peer_id,
                       sender_notice(sender_id, sender),
                       disable_notification: true
                     ),
                   {:ok, _message_id} <-
                     Telegex.copy_message(peer_id, sender_id, message_id,
                       disable_notification: true
                     ) do
                :ok
              end

            case result do
              :ok -> :ok
              {:error, _reason} -> relay_failed(sender_id)
            end

          _ ->
            relay_failed(sender_id)
        end

        {:stop, context}
    end
  end

  defp relay_failed(sender_id) do
    PrivateRelays.close_for(sender_id)
    Telegex.send_message(sender_id, "客服暂时无法接收消息，转发已关闭。")
  end

  defp sender_notice(sender_id, sender) do
    first_name = Map.get(sender, :first_name)
    last_name = Map.get(sender, :last_name)
    username = Map.get(sender, :username)

    display_name =
      [first_name, last_name]
      |> Enum.filter(&is_binary/1)
      |> Enum.join(" ")
      |> String.replace(~r/[\r\n]+/, " ")

    identity =
      cond do
        display_name != "" and is_binary(username) and username != "" ->
          "#{display_name} (@#{username})"

        display_name != "" ->
          display_name

        is_binary(username) and username != "" ->
          "@#{username}"

        true ->
          "未设置昵称"
      end

    "📨 新联系人消息\n发送者：#{identity}\n用户 ID：#{sender_id}"
  end
end
