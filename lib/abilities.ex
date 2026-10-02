defmodule Abilities do
  @moduledoc false

  alias PolicrMini.Uses
  alias PolicrMini.Schema.User

  require Logger

  defimpl Canada.Can, for: Plug.Conn do
    alias Plug.Conn

    @impl true
    def can?(%Conn{assigns: %{user: user}}, :write, %{"chat_id" => chat_id}) do
      if permission = Uses.get_permission(chat_id, user.id) do
        permission.configurable || permission.tg_is_owner
      else
        false
      end
    end
  end

  defimpl Canada.Can, for: User do
    alias PolicrMini.Instances.Chat
    alias PolicrMini.Chats.Scheme
    alias PolicrMini.Chats.CustomKit
    alias PolicrMini.Chats.Verification

    @impl true
    def can?(%User{id: user_id}, action, %Chat{id: chat_id})
        when action in [
               :stats,
               :scheme,
               :customs,
               :verifications,
               :operations,
               :health,
               :show,
               :index,
               :forbidden_words,
               :keyword_replies,
               :forbidden_whitelist,
               :moderation_events,
               :schedules,
               :lotteries,
               :members
             ] do
      if permission = Uses.get_permission(chat_id, user_id) do
        permission.readable || permission.tg_is_owner
      else
        false
      end
    end

    def can?(%User{id: user_id}, action, %Chat{id: chat_id})
        when action in [
               :update,
               :copy_settings,
               :takeover,
               :leave,
               :add_forbidden_word,
               :delete_forbidden_word,
               :add_keyword_reply,
               :update_keyword_reply,
               :delete_keyword_reply,
               :add_forbidden_whitelist,
               :delete_forbidden_whitelist,
               :add_schedule,
               :update_schedule,
               :delete_schedule
             ] do
      if permission = Uses.get_permission(chat_id, user_id) do
        permission.configurable || permission.tg_is_owner
      else
        false
      end
    end

    def can?(%User{id: user_id}, action, %Chat{id: chat_id})
        when action in [:create, :draw, :cancel, :kick_member, :sync_members] do
      if permission = Uses.get_permission(chat_id, user_id) do
        permission.writable || permission.tg_is_owner
      else
        false
      end
    end

    @impl true
    def can?(%User{id: user_id}, action, %CustomKit{chat_id: chat_id})
        when action in [:add, :update, :delete] do
      if permission = Uses.get_permission(chat_id, user_id) do
        permission.configurable || permission.tg_is_owner
      else
        false
      end
    end

    def can?(%User{id: user_id}, :update, %Scheme{chat_id: chat_id}) do
      permission = Uses.get_permission(chat_id, user_id)
      permission != nil and (permission.configurable || permission.tg_is_owner)
    end

    def can?(%User{id: user_id}, :kill, %Verification{chat_id: chat_id}) do
      permission = Uses.get_permission(chat_id, user_id)
      permission != nil and (permission.writable || permission.tg_is_owner)
    end

    def can?(%User{id: user_id}, action, %Chat{id: chat_id})
        when action in [:manage_permissions, :update_permission] do
      permission = Uses.get_permission(chat_id, user_id)
      permission != nil and permission.tg_is_owner
    end

    @impl true
    def can?(%User{}, action, subject) do
      Logger.warning("Unknown user action: #{inspect(action)} on subject: #{inspect(subject)}")
      false
    end
  end
end
