defmodule PolicrMiniBot.TrackGroupMemberChain do
  @moduledoc false

  use PolicrMiniBot.Chain

  alias PolicrMini.Members

  @impl true
  def handle(update, context) do
    update
    |> observed_members()
    |> Enum.each(fn
      {chat_id, user, source, opts} when is_integer(chat_id) and chat_id < 0 ->
        Members.track(chat_id, user, source, opts)

      _ ->
        :ok
    end)

    {:ok, context}
  end

  defp observed_members(%{chat_member: %{chat: chat, new_chat_member: member}}) do
    [{chat.id, member.user, "member_update", force: true, status: member_status(member)}]
  end

  defp observed_members(%{chat_join_request: %{chat: chat, from: user}}) do
    [{chat.id, user, "join_request", []}]
  end

  defp observed_members(%{callback_query: %{from: user, message: %{chat: chat}}}) do
    [{chat.id, user, "callback", []}]
  end

  defp observed_members(%{
         message: %{
           from: user,
           reply_to_message: %{from: replied_user},
           chat: %{type: type} = chat
         }
       })
       when type in ["group", "supergroup"] do
    [
      {chat.id, user, "message", []},
      {chat.id, replied_user, "reply_target", force: true}
    ]
  end

  defp observed_members(%{message: %{from: user, chat: %{type: type} = chat}})
       when type in ["group", "supergroup"] do
    [{chat.id, user, "message", []}]
  end

  defp observed_members(_update), do: []

  defp member_status(%{status: "restricted", is_member: false}), do: "left"
  defp member_status(%{status: status})
       when status in ["creator", "administrator", "left", "kicked"],
       do: status

  defp member_status(%{status: "restricted"}), do: "restricted"
  defp member_status(_member), do: "member"
end
