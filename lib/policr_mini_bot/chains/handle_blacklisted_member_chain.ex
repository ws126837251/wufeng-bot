defmodule PolicrMiniBot.HandleBlacklistedMemberChain do
  @moduledoc false

  use PolicrMiniBot.Chain

  alias PolicrMini.Members.Blacklist

  require Logger

  @impl true
  def match?(_update, %{taken_over: false}), do: false

  def match?(%{chat_join_request: %{chat: chat, from: user}}, _context),
    do: Blacklist.active?(chat.id, user.id)

  def match?(
        %{chat_member: %{chat: chat, new_chat_member: %{user: user}}},
        %{action: :user_joined}
      ),
      do: Blacklist.active?(chat.id, user.id)

  def match?(_update, _context), do: false

  @impl true
  def handle(%{chat_join_request: %{chat: chat, from: user}}, context) do
    case Blacklist.reject_join_request(chat.id, user.id) do
      :ok -> :ok
      {:error, error} ->
        Logger.warning("Blacklisted join request could not be declined: #{error}", chat_id: chat.id)
    end

    {:stop, context}
  end

  def handle(%{chat_member: %{chat: chat, new_chat_member: %{user: user}}}, context) do
    case Blacklist.reject_joined_member(chat.id, user.id) do
      :ok -> :ok
      {:error, error} ->
        Logger.warning("Blacklisted member could not be banned: #{error}", chat_id: chat.id)
    end

    {:stop, context}
  end
end
