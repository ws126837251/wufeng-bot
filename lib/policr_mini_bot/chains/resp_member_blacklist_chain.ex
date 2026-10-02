defmodule PolicrMiniBot.RespMemberBlacklistChain do
  @moduledoc "群内永久拉黑成员命令。"

  use PolicrMiniBot.Chain, {:command, :ban}

  alias PolicrMini.Automation.MessageTemplates
  alias PolicrMini.Instances.Chat
  alias PolicrMini.{ManagementApprovals, Members}
  alias PolicrMiniBot.TelegramText

  require Logger

  @group_types ["group", "supergroup"]
  @username ~r/^@[A-Za-z0-9_]{1,32}$/
  @user_id ~r/^\d+$/

  @impl true
  def match?(%{text: text, chat: %{type: type}}, context)
      when is_binary(text) and type in @group_types do
    command = text |> String.split(~r/\s+/, parts: 2, trim: true) |> List.first()
    bot_username = context |> Map.get(:bot, %{}) |> Map.get(:username)
    command_token?(command, bot_username) or command_target_token?(command, bot_username)
  end

  def match?(_message, _context), do: false

  @impl true
  def handle(
        %{chat: %{id: chat_id}, message_id: message_id} = message,
        %{from_admin: true} = context
      ) do
    bot_username = context |> Map.get(:bot, %{}) |> Map.get(:username)

    case parse_request(message, bot_username) do
      {:ok, target_query, reason} ->
        request_blacklist(chat_id, message_id, target_query, reason, context)

      {:error, :reason_too_long} ->
        reply_and_cleanup(
          chat_id,
          message_id,
          MessageTemplates.render(chat_id, :member_blacklist_command_failed, %{
            reason: "处理原因不能超过 200 个字符"
          }),
          context
        )

      {:error, :usage} ->
        reply_and_cleanup(
          chat_id,
          message_id,
          MessageTemplates.render(chat_id, :member_blacklist_command_usage),
          context
        )
    end
  end

  def handle(%{chat: %{id: chat_id}, message_id: message_id}, context) do
    reply_and_cleanup(
      chat_id,
      message_id,
      MessageTemplates.render(chat_id, :member_blacklist_command_admin_only),
      context
    )
  end

  def command_token?(token, bot_username) when is_binary(token) do
    case String.split(token, "@", parts: 2) do
      [@command] ->
        true

      [@command, mentioned_bot] when is_binary(bot_username) ->
        String.downcase(mentioned_bot) == String.downcase(bot_username)

      _ ->
        false
    end
  end

  def command_token?(_token, _bot_username), do: false

  def command_target_token?(token, bot_username) when is_binary(token) do
    case String.split(token, "@", parts: 2) do
      [@command, target] when target != "" ->
        not same_username?(target, bot_username) and Regex.match?(@username, "@#{target}")

      _ ->
        false
    end
  end

  def command_target_token?(_token, _bot_username), do: false

  def parse_request(message, bot_username \\ nil)

  def parse_request(%{text: text} = message, bot_username) when is_binary(text) do
    case selected_member_request(message, bot_username) do
      {:ok, target, reason} ->
        validate_request(target, reason)

      :none ->
        {command_target, arguments} = command_target_and_arguments(text, bot_username)
        parts = String.split(arguments, ~r/\s+/, trim: true)

        cond do
          command_target ->
            validate_request(command_target, arguments)

          parts != [] and target_token?(hd(parts)) ->
            [target | reason_parts] = parts
            validate_request(target, Enum.join(reason_parts, " "))

          reply_user_id = reply_user_id(message) ->
            validate_request(Integer.to_string(reply_user_id), arguments)

          true ->
            {:error, :usage}
        end
    end
  end

  defp request_blacklist(chat_id, message_id, target_query, reason, context) do
    with {:ok, target} <- Members.resolve_target(chat_id, target_query),
         {:ok, telegram_member} <- Telegex.get_chat_member(chat_id, target.user_id),
         :ok <- Members.protect_target(telegram_member),
         {:ok, reply_text} <- dispatch_blacklist(chat_id, target, reason, context) do
      reply_and_cleanup(
        chat_id,
        message_id,
        reply_text,
        context
      )
    else
      {:error, reason_code} when reason_code in [:invalid_target, :not_found, :not_a_member] ->
        not_found(chat_id, message_id, target_query, context)

      {:error, reason_code} when reason_code in [:admin_protected, :bot_protected] ->
        protected(chat_id, message_id, target_query, context)

      {:error, :owner_private_chat_unavailable} ->
        reply_and_cleanup(
          chat_id,
          message_id,
          MessageTemplates.render(chat_id, :management_approval_owner_unavailable),
          context
        )

      {:error, error} ->
        Logger.warning("Member blacklist command failed: #{inspect(error)}",
          chat_id: chat_id
        )

        reply_and_cleanup(
          chat_id,
          message_id,
          MessageTemplates.render(chat_id, :member_blacklist_command_failed, %{
            reason: human_error(error)
          }),
          context
        )
    end
  end

  @doc false
  def execution_mode(%{from_owner: true}), do: :direct
  def execution_mode(_context), do: :approval

  defp dispatch_blacklist(chat_id, target, reason, context) do
    dispatch_blacklist(execution_mode(context), chat_id, target, reason, context)
  end

  defp dispatch_blacklist(:direct, chat_id, target, reason, context) do
    with {:ok, chat} <- Chat.get(chat_id),
         {:ok, member} <- Members.kick(chat, context.user_id, target.user_id, reason) do
      {:ok,
       MessageTemplates.render(chat_id, :member_blacklist_command_success, %{
         target: member_label(member)
       })}
    end
  end

  defp dispatch_blacklist(:approval, chat_id, target, reason, context) do
    with {:ok, _approval} <- submit_approval(chat_id, target, reason, context.user_id) do
      {:ok, MessageTemplates.render(chat_id, :management_approval_submitted)}
    end
  end

  defp submit_approval(chat_id, target, reason, requester_user_id) do
    path = "/console/v2/api/chats/#{chat_id}/members/#{target.user_id}/blacklist"
    summary = blacklist_summary(target, reason)

    ManagementApprovals.request_action(
      chat_id,
      requester_user_id,
      "POST",
      path,
      %{"reason" => reason},
      "MemberController.kick",
      summary
    )
  end

  defp blacklist_summary(target, reason) do
    base = "永久拉黑成员｜#{member_label(target)}"
    if reason == "", do: base, else: "#{base}｜原因：#{reason}"
  end

  defp member_label(member) do
    username = if member.username, do: " @#{member.username}", else: ""
    "#{member.full_name}#{username}（ID #{member.user_id}）"
  end

  defp not_found(chat_id, message_id, target, context) do
    reply_and_cleanup(
      chat_id,
      message_id,
      MessageTemplates.render(chat_id, :member_blacklist_command_not_found, %{target: target}),
      context
    )
  end

  defp protected(chat_id, message_id, target, context) do
    reply_and_cleanup(
      chat_id,
      message_id,
      MessageTemplates.render(chat_id, :member_blacklist_command_protected, %{target: target}),
      context
    )
  end

  defp command_target_and_arguments(text, bot_username) do
    case String.split(text, ~r/\s+/, parts: 2, trim: true) do
      [command, arguments] ->
        {command_target(command, bot_username), String.trim(arguments)}

      [command] ->
        {command_target(command, bot_username), ""}

      _ ->
        {nil, ""}
    end
  end

  defp command_target(command, bot_username) do
    if command_target_token?(command, bot_username) do
      [@command, target] = String.split(command, "@", parts: 2)
      "@#{target}"
    end
  end

  defp selected_member_request(message, bot_username) do
    text = Map.fetch!(message, :text)

    message
    |> Map.get(:entities, [])
    |> List.wrap()
    |> Enum.filter(&selected_member_entity?(&1, text, bot_username))
    |> Enum.min_by(&entity_offset/1, fn -> nil end)
    |> case do
      nil ->
        :none

      entity ->
        user = Map.get(entity, :user)

        reason =
          text
          |> TelegramText.utf16_after(entity_offset(entity) + entity_length(entity))
          |> String.trim()

        {:ok, Integer.to_string(user.id), reason}
    end
  end

  defp selected_member_entity?(entity, text, bot_username) do
    user = Map.get(entity, :user)
    offset = entity_offset(entity)

    entity_type(entity) == "text_mention" and is_map(user) and is_integer(Map.get(user, :id)) and
      offset >= String.length(@command) and
      command_token?(text |> TelegramText.utf16_slice(0, offset) |> String.trim(), bot_username)
  end

  defp entity_type(entity), do: Map.get(entity, :type, Map.get(entity, "type"))
  defp entity_offset(entity), do: Map.get(entity, :offset, Map.get(entity, "offset", 0))
  defp entity_length(entity), do: Map.get(entity, :length, Map.get(entity, "length", 0))

  defp same_username?(_username, nil), do: false

  defp same_username?(username, bot_username),
    do: String.downcase(username) == String.downcase(bot_username)

  defp target_token?(token), do: Regex.match?(@username, token) or Regex.match?(@user_id, token)

  defp validate_request(target, reason) do
    reason = String.trim(reason)
    if String.length(reason) <= 200, do: {:ok, target, reason}, else: {:error, :reason_too_long}
  end

  defp reply_user_id(%{reply_to_message: %{from: %{id: user_id}}}) when is_integer(user_id),
    do: user_id

  defp reply_user_id(_message), do: nil

  defp human_error(%Telegex.Error{description: description}), do: description
  defp human_error(%Telegex.RequestError{}), do: "Telegram 请求失败，请稍后重试"
  defp human_error(:requester_not_found), do: "无法识别命令申请人"
  defp human_error(:owner_not_found), do: "无法核对当前群主"
  defp human_error(:owner_lookup_failed), do: "暂时无法核对当前群主"
  defp human_error(:ban_status_not_confirmed), do: "Telegram 未确认成员已经被移出，请稍后重试"
  defp human_error(error), do: inspect(error, limit: 5)

  defp reply_and_cleanup(chat_id, message_id, text, context) do
    send_text(chat_id, text,
      reply_to_message_id: message_id,
      auto_delete_after: 10,
      logging: true
    )

    async_delete_message(chat_id, message_id)
    {:stop, %{context | deleted: true}}
  end
end
