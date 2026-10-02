defmodule PolicrMini.Members do
  @moduledoc false

  import Ecto.Query
  import PolicrMiniBot.Helper, only: [can_restrict_members?: 1, is_administrator?: 1]

  alias PolicrMini.Instances.Chat
  alias PolicrMini.Members.{ActionLog, Blacklist, BlacklistEntry, GroupMember}
  alias PolicrMini.Repo
  alias PolicrMini.Schema.User

  @cache :wufeng_group_member_cache

  def track(chat_id, user, source, opts \\ [])

  def track(chat_id, user, source, opts)
      when is_integer(chat_id) and chat_id < 0 and is_map(user) do
    force? = Keyword.get(opts, :force, false)
    key = {chat_id, user.id}

    if force? or not remembered?(key) do
      case persist_member(chat_id, user, source, opts, force?) do
        {:ok, _member} = result ->
          remember(key)
          result

        error ->
          forget(key)
          error
      end
    else
      :ok
    end
  end

  def track(_chat_id, _user, _source, _opts), do: :ok

  defp persist_member(chat_id, user, source, opts, force?) do
    with {:ok, _user} <- upsert_user(user, force?),
         {:ok, member} <- upsert_member(chat_id, user, source, opts) do
      {:ok, member}
    end
  end

  def search(chat_id, query \\ "", limit \\ 30) do
    term = query |> to_string() |> String.trim() |> String.trim_leading("@")
    pattern = "%#{escape_like(term)}%"

    filter =
      if term == "" do
        true
      else
        dynamic(
          [m, u],
          ilike(u.username, ^pattern) or ilike(u.first_name, ^pattern) or
            ilike(u.last_name, ^pattern) or
            ilike(fragment("concat_ws(' ', ?, ?)", u.first_name, u.last_name), ^pattern) or
            ilike(fragment("CAST(? AS TEXT)", u.id), ^pattern)
        )
      end

    from(m in GroupMember,
      join: u in User,
      on: u.id == m.user_id,
      left_join: b in BlacklistEntry,
      on: b.chat_id == m.chat_id and b.user_id == m.user_id and b.active == true,
      where: m.chat_id == ^chat_id,
      where: m.status not in ["left", "kicked"],
      where: is_nil(b.id),
      where: ^filter,
      order_by: [desc: m.inserted_at],
      limit: ^min(max(limit, 1), 50),
      preload: [user: u]
    )
    |> Repo.all()
    |> Enum.map(&member_map/1)
  end

  def resolve_query(chat_id, query) do
    query = query |> to_string() |> String.trim()

    case Integer.parse(query) do
      {user_id, ""} -> resolve_member_id(chat_id, user_id, "direct_lookup")
      _ -> resolve_username(chat_id, query)
    end
  end

  def resolve_target(chat_id, query) do
    query = query |> to_string() |> String.trim()

    with {:ok, filter} <- target_filter(query) do
      _ = resolve_query(chat_id, query)

      from(m in GroupMember,
        join: u in User,
        on: u.id == m.user_id,
        left_join: b in BlacklistEntry,
        on: b.chat_id == m.chat_id and b.user_id == m.user_id and b.active == true,
        where: m.chat_id == ^chat_id,
        where: m.status not in ["left", "kicked"],
        where: is_nil(b.id),
        where: ^filter,
        preload: [user: u],
        limit: 1
      )
      |> Repo.one()
      |> case do
        nil -> {:error, :not_found}
        member -> {:ok, member_map(member)}
      end
    end
  end

  def list_actions(chat_id, limit \\ 30) do
    from(log in ActionLog,
      where: log.chat_id == ^chat_id,
      order_by: [desc: log.inserted_at],
      limit: ^min(max(limit, 1), 50)
    )
    |> Repo.all()
    |> Enum.map(&action_map/1)
  end

  def kick(%Chat{} = chat, actor_user_id, target_user_id, reason \\ nil) do
    with {:ok, target} <- Telegex.get_chat_member(chat.id, target_user_id),
         :ok <- protect_target(target),
         :ok <- ensure_bot_can_restrict(chat.id),
         {:ok, _entry} <- Blacklist.put(chat.id, actor_user_id, target.user, reason),
         {:ok, true} <- enforce_blacklist(chat.id, target_user_id) do
      mark_status(chat.id, target.user, "kicked", "member_blacklist")
      log_action(chat.id, actor_user_id, target.user, reason, "success", nil)
      {:ok, member_payload(chat.id, target.user, "kicked", "member_blacklist")}
    else
      {:error, reason_code} = error when is_atom(reason_code) ->
        log_failed(chat.id, actor_user_id, target_user_id, reason, reason_code)
        error

      {:error, error} ->
        message = telegram_error(error)
        log_failed(chat.id, actor_user_id, target_user_id, reason, message)
        {:error, message}

      other ->
        message = telegram_error(other)
        log_failed(chat.id, actor_user_id, target_user_id, reason, message)
        {:error, message}
    end
  end

  defp enforce_blacklist(chat_id, user_id) do
    Blacklist.enforce_member(chat_id, user_id)
  end

  @doc false
  def protect_target(member, bot_id \\ PolicrMiniBot.id()) do
    cond do
      member.user.id == bot_id ->
        {:error, :bot_protected}

      member.status in ["creator", "administrator"] ->
        {:error, :admin_protected}

      member.status in ["left", "kicked"] ->
        {:error, :not_a_member}

      member.status == "restricted" and Map.get(member, :is_member) == false ->
        {:error, :not_a_member}

      true ->
        :ok
    end
  end

  defp ensure_bot_can_restrict(chat_id) do
    case Telegex.get_chat_member(chat_id, PolicrMiniBot.id()) do
      {:ok, member} ->
        if is_administrator?(member) and can_restrict_members?(member),
          do: :ok,
          else: {:error, :bot_permission_missing}

      {:error, error} ->
        {:error, telegram_error(error)}
    end
  end

  defp upsert_user(user, refresh?) do
    attrs = %{
      id: user.id,
      token_ver: 0,
      first_name: Map.get(user, :first_name),
      last_name: Map.get(user, :last_name),
      username: Map.get(user, :username)
    }

    conflict =
      if refresh? do
        refreshed = attrs |> Map.drop([:id, :token_ver]) |> Map.put(:updated_at, now())
        [set: Map.to_list(refreshed)]
      else
        :nothing
      end

    %User{id: user.id, token_ver: 0}
    |> User.changeset(attrs)
    |> Repo.insert(on_conflict: conflict, conflict_target: :id, returning: true)
  end

  defp upsert_member(chat_id, user, source, opts) do
    attrs = %{
      chat_id: chat_id,
      user_id: user.id,
      status: Keyword.get(opts, :status, "member"),
      source: source,
      is_bot: Map.get(user, :is_bot, false)
    }

    conflict =
      if Keyword.get(opts, :force, false) do
        [set: [status: attrs.status, source: source, is_bot: attrs.is_bot, updated_at: now()]]
      else
        :nothing
      end

    %GroupMember{}
    |> GroupMember.changeset(attrs)
    |> Repo.insert(
      on_conflict: conflict,
      conflict_target: [:chat_id, :user_id],
      returning: true
    )
  end

  defp mark_status(chat_id, user, status, source) do
    forget({chat_id, user.id})
    track(chat_id, user, source, force: true, status: status)
  end

  defp log_failed(chat_id, actor_id, target_id, reason, error) do
    user = Repo.get(User, target_id)

    attrs = %{
      chat_id: chat_id,
      actor_user_id: actor_id,
      target_user_id: target_id,
      target_display_name: user && User.full_name(user),
      target_username: user && user.username,
      action: "kick",
      reason: blank_to_nil(reason),
      status: "failed",
      telegram_error: String.slice(to_string(error), 0, 1000)
    }

    %ActionLog{} |> ActionLog.changeset(attrs) |> Repo.insert()
  end

  defp log_action(chat_id, actor_id, user, reason, status, error) do
    attrs = %{
      chat_id: chat_id,
      actor_user_id: actor_id,
      target_user_id: user.id,
      target_display_name: display_name(user),
      target_username: Map.get(user, :username),
      action: "kick",
      reason: blank_to_nil(reason),
      status: status,
      telegram_error: error
    }

    %ActionLog{} |> ActionLog.changeset(attrs) |> Repo.insert()
  end

  defp member_map(%GroupMember{user: user} = member) do
    member_payload(member.chat_id, user, member.status, member.source, member.is_bot)
    |> Map.put(:first_seen_at, member.inserted_at)
  end

  defp member_payload(chat_id, user, status, source, is_bot \\ nil) do
    is_bot = if is_nil(is_bot), do: Map.get(user, :is_bot, false), else: is_bot

    %{
      chat_id: chat_id,
      user_id: user.id,
      full_name: display_name(user),
      username: Map.get(user, :username),
      photo_url: "/console/v2/#{user.id}/photo",
      status: status,
      source: source,
      is_bot: is_bot,
      removable: removable?(user.id, status)
    }
  end

  defp action_map(log) do
    Map.take(log, [
      :id,
      :actor_user_id,
      :target_user_id,
      :target_display_name,
      :target_username,
      :action,
      :reason,
      :status,
      :telegram_error,
      :inserted_at
    ])
  end

  defp display_name(%User{} = user), do: User.full_name(user)

  defp display_name(user) do
    [Map.get(user, :first_name), Map.get(user, :last_name)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
    |> case do
      "" -> "用户 #{user.id}"
      name -> name
    end
  end

  defp normalize_status(%{status: "restricted", is_member: false}), do: "left"

  defp normalize_status(%{status: status})
       when status in ["creator", "administrator", "left", "kicked"],
       do: status

  defp normalize_status(%{status: "restricted"}), do: "restricted"
  defp normalize_status(_member), do: "member"

  defp target_filter("@" <> username = query) do
    if Regex.match?(~r/^@[A-Za-z0-9_]{1,32}$/, query) do
      normalized = String.downcase(username)
      {:ok, dynamic([_m, u, _b], fragment("lower(?)", u.username) == ^normalized)}
    else
      {:error, :invalid_target}
    end
  end

  defp target_filter(query) do
    case Integer.parse(query) do
      {user_id, ""} when user_id > 0 -> {:ok, dynamic([_m, u, _b], u.id == ^user_id)}
      _ -> {:error, :invalid_target}
    end
  end

  defp resolve_username(chat_id, "@" <> username = query) do
    if Regex.match?(~r/^@[A-Za-z0-9_]{1,32}$/, query) do
      case known_user_id(username) do
        nil -> resolve_public_username(chat_id, query)
        user_id -> resolve_member_id(chat_id, user_id, "known_username_lookup")
      end
    else
      :ok
    end
  end

  defp resolve_username(_chat_id, _query), do: :ok

  defp resolve_public_username(chat_id, query) do
    case Telegex.get_chat(query) do
      {:ok, resolved_chat} -> resolve_member_id(chat_id, resolved_chat.id, "username_lookup")
      _ -> :ok
    end
  end

  defp known_user_id(username) do
    normalized = String.downcase(username)

    from(u in User,
      where: fragment("lower(?)", u.username) == ^normalized,
      select: u.id,
      limit: 1
    )
    |> Repo.one()
  end

  defp resolve_member_id(chat_id, user_id, source) do
    with {:ok, chat_member} <- Telegex.get_chat_member(chat_id, user_id) do
      track(chat_id, chat_member.user, source,
        force: true,
        status: normalize_status(chat_member)
      )
    else
      _ -> :ok
    end
  end

  defp removable?(user_id, status) do
    user_id != PolicrMiniBot.id() and status not in ["creator", "administrator", "left", "kicked"]
  end

  defp escape_like(term) do
    term
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value),
    do: if(String.trim(to_string(value)) == "", do: nil, else: String.trim(to_string(value)))

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp telegram_error(%Telegex.Error{description: description}), do: description

  defp telegram_error(%Telegex.RequestError{reason: reason}),
    do: "Telegram请求失败：#{inspect(reason)}"

  defp telegram_error(value) when is_binary(value), do: value
  defp telegram_error(value), do: inspect(value, limit: 10)

  defp remembered?(key), do: :ets.member(ensure_cache(), key)
  defp remember(key), do: :ets.insert(ensure_cache(), {key, true})

  defp forget(key) do
    case :ets.whereis(@cache) do
      :undefined -> :ok
      table -> :ets.delete(table, key)
    end
  end

  defp ensure_cache do
    case :ets.whereis(@cache) do
      :undefined ->
        try do
          :ets.new(@cache, [:named_table, :public, :set, read_concurrency: true])
        rescue
          ArgumentError -> :ets.whereis(@cache)
        end

      table ->
        table
    end
  end
end
