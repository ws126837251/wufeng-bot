defmodule PolicrMini.Automation do
  @moduledoc """
  持久化的群组自动化设置、关键词规则、定时消息和消息删除任务。

  所有延时任务写入 PostgreSQL，服务重启后仍会继续执行。
  """

  import Ecto.Query

  alias PolicrMini.Automation.{
    ChatSetting,
    ForbiddenWhitelistRule,
    ForbiddenWordRule,
    KeywordReplyRule,
    MessageTemplates,
    MessageDeleteJob,
    ModerationEvent,
    ScheduledMessage
  }

  alias PolicrMini.Repo

  @max_delete_seconds 172_740

  def get_settings!(chat_id) do
    chat_id = normalize_chat_id!(chat_id)

    case Repo.get(ChatSetting, chat_id) do
      nil ->
        %ChatSetting{chat_id: chat_id}
        |> Repo.insert(on_conflict: :nothing)

        Repo.get!(ChatSetting, chat_id)

      setting ->
        setting
    end
  end

  def update_settings(chat_id, attrs) do
    chat_id
    |> get_settings!()
    |> ChatSetting.changeset(attrs)
    |> Repo.update()
  end

  def list_forbidden_words(chat_id) do
    Repo.all(
      from rule in ForbiddenWordRule,
        where: rule.chat_id == ^normalize_chat_id!(chat_id),
        order_by: [asc: rule.word]
    )
  end

  def create_forbidden_word(chat_id, attrs) do
    attrs =
      attrs
      |> Map.put("chat_id", normalize_chat_id!(chat_id))
      |> Map.put_new("match_mode", "contains")
      |> Map.put_new("case_sensitive", false)
      |> Map.put_new("enabled", true)
      |> Map.put_new("action", "delete_warn")

    %ForbiddenWordRule{}
    |> ForbiddenWordRule.changeset(attrs)
    |> Repo.insert()
  end

  def delete_forbidden_word(chat_id, id) do
    rule =
      Repo.one(
        from rule in ForbiddenWordRule,
          where: rule.chat_id == ^normalize_chat_id!(chat_id) and rule.id == ^id
      )

    if rule, do: Repo.delete(rule), else: {:error, :not_found}
  end

  def list_keyword_replies(chat_id) do
    Repo.all(
      from rule in KeywordReplyRule,
        where: rule.chat_id == ^normalize_chat_id!(chat_id),
        order_by: [asc: rule.keyword, asc: rule.id]
    )
  end

  def create_keyword_reply(chat_id, attrs) do
    attrs =
      attrs
      |> Map.put("chat_id", normalize_chat_id!(chat_id))
      |> Map.put_new("match_mode", "contains")
      |> Map.put_new("case_sensitive", false)
      |> Map.put_new("enabled", true)
      |> Map.put_new("buttons", [])

    %KeywordReplyRule{}
    |> KeywordReplyRule.changeset(attrs)
    |> Repo.insert()
  end

  def update_keyword_reply(chat_id, id, attrs) do
    with %KeywordReplyRule{} = rule <- get_keyword_reply(chat_id, id) do
      rule |> KeywordReplyRule.changeset(attrs) |> Repo.update()
    else
      nil -> {:error, :not_found}
    end
  end

  def delete_keyword_reply(chat_id, id) do
    case get_keyword_reply(chat_id, id) do
      %KeywordReplyRule{} = rule -> Repo.delete(rule)
      nil -> {:error, :not_found}
    end
  end

  def find_keyword_reply(chat_id, text) when is_binary(text) do
    Repo.all(
      from rule in KeywordReplyRule,
        where: rule.chat_id == ^normalize_chat_id!(chat_id) and rule.enabled
    )
    |> Enum.flat_map(fn rule ->
      case longest_matching_keyword(rule, text) do
        nil -> []
        keyword -> [{rule, keyword}]
      end
    end)
    |> Enum.max_by(fn {rule, keyword} -> {String.length(keyword), -rule.id} end, fn -> nil end)
    |> case do
      {rule, _keyword} -> rule
      nil -> nil
    end
  end

  def find_keyword_reply(_chat_id, _text), do: nil

  @doc false
  def text_matches?(rule, text) when is_binary(text) do
    not is_nil(longest_matching_keyword(rule, text))
  end

  @doc false
  def longest_matching_keyword(rule, text) when is_binary(text) do
    rule
    |> rule_keywords()
    |> Enum.filter(&keyword_matches?(rule, &1, text))
    |> Enum.max_by(&String.length/1, fn -> nil end)
  end

  defp keyword_matches?(rule, configured_keyword, text) do
    {keyword, text} =
      if rule.case_sensitive do
        {configured_keyword, text}
      else
        {String.downcase(configured_keyword), String.downcase(text)}
      end

    case Map.get(rule, :match_mode, "contains") do
      "exact" -> text == keyword
      "prefix" -> String.starts_with?(text, keyword)
      _ -> String.contains?(text, keyword)
    end
  end

  defp rule_keywords(rule) do
    case Map.get(rule, :keywords) do
      keywords when is_list(keywords) and keywords != [] -> keywords
      _ -> [Map.get(rule, :keyword) || Map.get(rule, :word)]
    end
    |> Enum.filter(&is_binary/1)
  end

  def list_forbidden_whitelist(chat_id) do
    Repo.all(
      from rule in ForbiddenWhitelistRule,
        where: rule.chat_id == ^normalize_chat_id!(chat_id),
        order_by: [asc: rule.word]
    )
  end

  def create_forbidden_whitelist_rule(chat_id, attrs) do
    attrs =
      attrs
      |> Map.put("chat_id", normalize_chat_id!(chat_id))
      |> Map.put_new("match_mode", "contains")
      |> Map.put_new("case_sensitive", false)
      |> Map.put_new("enabled", true)

    %ForbiddenWhitelistRule{}
    |> ForbiddenWhitelistRule.changeset(attrs)
    |> Repo.insert()
  end

  def delete_forbidden_whitelist_rule(chat_id, id) do
    rule =
      Repo.one(
        from rule in ForbiddenWhitelistRule,
          where: rule.chat_id == ^normalize_chat_id!(chat_id) and rule.id == ^id
      )

    if rule, do: Repo.delete(rule), else: {:error, :not_found}
  end

  def find_forbidden_word(chat_id, text) when is_binary(text) do
    setting = get_settings!(chat_id)

    if setting.forbidden_enabled and not whitelisted?(chat_id, text) do
      matching_rules(chat_id)
      |> Enum.find(&rule_matches?(&1, text))
    end
  end

  def find_forbidden_word(_chat_id, _text), do: nil

  def resolve_moderation_action(chat_id, user_id, %ForbiddenWordRule{} = rule) do
    setting = get_settings!(chat_id)

    if setting.forbidden_escalation_enabled and rule.action == "delete_warn" and
         is_integer(user_id) do
      case recent_moderation_count(chat_id, user_id) do
        0 -> "delete_warn"
        1 -> "mute_10m"
        2 -> "mute_1h"
        _ -> "ban"
      end
    else
      rule.action
    end
  end

  def create_moderation_event(chat_id, attrs) do
    attrs =
      attrs
      |> Map.put("chat_id", normalize_chat_id!(chat_id))
      |> Map.put_new("status", "applied")

    %ModerationEvent{}
    |> ModerationEvent.changeset(attrs)
    |> Repo.insert()
  end

  def list_moderation_events(chat_id) do
    Repo.all(
      from event in ModerationEvent,
        where: event.chat_id == ^normalize_chat_id!(chat_id),
        order_by: [desc: event.inserted_at, desc: event.id],
        limit: 80
    )
  end

  def list_schedules(chat_id) do
    Repo.all(
      from schedule in ScheduledMessage,
        where: schedule.chat_id == ^normalize_chat_id!(chat_id),
        order_by: [asc: schedule.next_run_at]
    )
  end

  def create_schedule(chat_id, attrs) do
    attrs =
      attrs
      |> Map.put("chat_id", normalize_chat_id!(chat_id))
      |> Map.put_new("schedule_type", "one_time")
      |> Map.put_new("enabled", true)
      |> Map.put_new("preserve_first_message", false)
      |> Map.put_new("delete_after_seconds", 0)
      |> Map.put_new("sent_count", 0)

    %ScheduledMessage{}
    |> ScheduledMessage.changeset(attrs)
    |> Repo.insert()
  end

  def update_schedule(chat_id, id, attrs) do
    with %ScheduledMessage{} = schedule <- get_schedule(chat_id, id),
         {:ok, schedule} <- schedule |> ScheduledMessage.changeset(attrs) |> Repo.update() do
      {:ok, schedule}
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def delete_schedule(chat_id, id) do
    case get_schedule(chat_id, id) do
      nil -> {:error, :not_found}
      schedule -> Repo.delete(schedule)
    end
  end

  def schedule_bot_message(chat_id, message, opts \\ []) do
    setting = get_settings!(chat_id)

    if setting.auto_delete_bot_messages && Keyword.get(opts, :auto_delete, true) &&
         is_map(message) do
      delay =
        if Keyword.has_key?(opts, :auto_delete_after) do
          Keyword.get(opts, :auto_delete_after)
        else
          setting.bot_message_delete_after_seconds
        end

      if is_integer(delay) && delay > 0 do
        schedule_delete(chat_id, message.message_id, delay, "bot_message")
      else
        :disabled
      end
    else
      :disabled
    end
  end

  def schedule_delete(chat_id, message_id, delay_seconds, kind \\ "bot_message") do
    delay_seconds = min(max(delay_seconds, 1), @max_delete_seconds)

    %MessageDeleteJob{}
    |> MessageDeleteJob.changeset(%{
      chat_id: normalize_chat_id!(chat_id),
      message_id: message_id,
      run_at: DateTime.add(DateTime.utc_now(), delay_seconds, :second),
      status: "pending",
      kind: kind,
      attempts: 0
    })
    |> Repo.insert()
  end

  def claim_due_delete_jobs(limit \\ 50) do
    Repo.transaction(fn ->
      jobs =
        Repo.all(
          from job in MessageDeleteJob,
            where: job.status == "pending" and job.run_at <= ^DateTime.utc_now(),
            order_by: [asc: job.run_at],
            limit: ^limit,
            lock: "FOR UPDATE SKIP LOCKED"
        )

      Enum.map(jobs, fn job ->
        {:ok, updated} =
          job
          |> MessageDeleteJob.changeset(%{status: "running", attempts: job.attempts + 1})
          |> Repo.update()

        updated
      end)
    end)
    |> case do
      {:ok, jobs} -> jobs
      {:error, reason} -> raise "claim delete jobs failed: #{inspect(reason)}"
    end
  end

  def finish_delete_job(%MessageDeleteJob{} = job, :ok) do
    job |> MessageDeleteJob.changeset(%{status: "completed"}) |> Repo.update()
  end

  def finish_delete_job(%MessageDeleteJob{} = job, {:error, reason}) do
    attrs =
      if job.attempts < 3 do
        %{
          status: "pending",
          run_at: DateTime.add(DateTime.utc_now(), 60, :second),
          last_error: inspect(reason)
        }
      else
        %{status: "failed", last_error: inspect(reason)}
      end

    job |> MessageDeleteJob.changeset(attrs) |> Repo.update()
  end

  def health_summary(chat_id) do
    chat_id = normalize_chat_id!(chat_id)
    now = DateTime.utc_now()

    %{
      pending_delete_jobs:
        Repo.aggregate(
          from(job in MessageDeleteJob,
            where: job.chat_id == ^chat_id and job.status == "pending"
          ),
          :count,
          :id
        ),
      failed_delete_jobs:
        Repo.aggregate(
          from(job in MessageDeleteJob, where: job.chat_id == ^chat_id and job.status == "failed"),
          :count,
          :id
        ),
      active_schedules:
        Repo.aggregate(
          from(schedule in ScheduledMessage,
            where: schedule.chat_id == ^chat_id and schedule.enabled
          ),
          :count,
          :id
        ),
      overdue_schedules:
        Repo.aggregate(
          from(schedule in ScheduledMessage,
            where:
              schedule.chat_id == ^chat_id and schedule.enabled and
                schedule.next_run_at <= ^now
          ),
          :count,
          :id
        ),
      failed_schedules:
        Repo.aggregate(
          from(schedule in ScheduledMessage,
            where: schedule.chat_id == ^chat_id and schedule.failure_count > 0
          ),
          :count,
          :id
        ),
      active_lotteries:
        Repo.aggregate(
          from(campaign in PolicrMini.Automation.LotteryCampaign,
            where: campaign.chat_id == ^chat_id and campaign.status == "active"
          ),
          :count,
          :id
        ),
      due_lotteries:
        Repo.aggregate(
          from(campaign in PolicrMini.Automation.LotteryCampaign,
            where:
              campaign.chat_id == ^chat_id and campaign.status == "active" and
                campaign.end_at <= ^now
          ),
          :count,
          :id
        )
    }
  end

  def claim_due_schedules(limit \\ 20) do
    Repo.transaction(fn ->
      schedules =
        Repo.all(
          from schedule in ScheduledMessage,
            where: schedule.enabled and schedule.next_run_at <= ^DateTime.utc_now(),
            order_by: [asc: schedule.next_run_at],
            limit: ^limit,
            lock: "FOR UPDATE SKIP LOCKED"
        )

      Enum.map(schedules, fn schedule ->
        attrs =
          case next_run_at(schedule) do
            nil -> %{enabled: false}
            next_run_at -> %{next_run_at: next_run_at}
          end

        {:ok, updated} = schedule |> ScheduledMessage.changeset(attrs) |> Repo.update()
        updated
      end)
    end)
    |> case do
      {:ok, schedules} -> schedules
      {:error, reason} -> raise "claim schedules failed: #{inspect(reason)}"
    end
  end

  def run_schedule(%ScheduledMessage{} = schedule) do
    opts = [auto_delete: false, disable_notification: true, logging: true]

    case PolicrMiniBot.MessageCaller.send_text(schedule.chat_id, schedule.text, opts) do
      {:ok, message} ->
        should_delete? =
          schedule.delete_after_seconds > 0 and
            (not schedule.preserve_first_message or schedule.sent_count > 0)

        if should_delete? do
          schedule_delete(
            schedule.chat_id,
            message.message_id,
            schedule.delete_after_seconds,
            "scheduled_message"
          )
        end

        schedule
        |> ScheduledMessage.changeset(%{
          sent_count: schedule.sent_count + 1,
          last_message_id: message.message_id,
          last_error: nil,
          failure_count: 0
        })
        |> Repo.update()

      {:error, reason} ->
        retry_at =
          DateTime.add(DateTime.utc_now(), retry_delay_seconds(schedule.failure_count), :second)

        schedule
        |> ScheduledMessage.changeset(%{
          next_run_at: retry_at,
          enabled: true,
          last_error: inspect(reason, limit: 12, printable_limit: 500),
          failure_count: schedule.failure_count + 1
        })
        |> Repo.update()

        {:error, reason}
    end
  end

  def test_schedule(chat_id, id) do
    with %ScheduledMessage{} = schedule <- get_schedule(chat_id, id),
         {:ok, message} <-
           PolicrMiniBot.MessageCaller.send_text(
             schedule.chat_id,
             MessageTemplates.render(schedule.chat_id, :scheduled_message_test, %{
               title: schedule.title,
               text: schedule.text
             }),
             auto_delete: false,
             disable_notification: true,
             logging: true
           ) do
      if schedule.delete_after_seconds > 0 do
        schedule_delete(
          schedule.chat_id,
          message.message_id,
          schedule.delete_after_seconds,
          "scheduled_message_test"
        )
      end

      {:ok, schedule, message}
    else
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def send_welcome(chat_id, user) do
    setting = get_settings!(chat_id)

    if setting.welcome_enabled && is_binary(setting.welcome_text) &&
         String.trim(setting.welcome_text) != "" do
      text = render_welcome(setting.welcome_text, user)

      PolicrMiniBot.MessageCaller.send_text(chat_id, text,
        auto_delete_after: setting.welcome_delete_after_seconds,
        disable_notification: true
      )
    else
      :disabled
    end
  end

  def settings_map(%ChatSetting{} = setting) do
    settings =
      setting
      |> Map.take([
        :chat_id,
        :auto_delete_bot_messages,
        :bot_message_delete_after_seconds,
        :welcome_enabled,
        :welcome_text,
        :welcome_delete_after_seconds,
        :forbidden_enabled,
        :forbidden_escalation_enabled,
        :forbidden_warning_text,
        :forbidden_warning_delete_after_seconds,
        :message_templates
      ])
      |> Map.update!(
        :message_templates,
        &PolicrMini.Automation.MessageTemplates.merged/1
      )

    Map.put(
      settings,
      :message_template_catalog,
      PolicrMini.Automation.MessageTemplates.catalog()
    )
  end

  def rule_map(%ForbiddenWordRule{} = rule),
    do:
      Map.take(rule, [
        :id,
        :chat_id,
        :word,
        :match_mode,
        :case_sensitive,
        :enabled,
        :warning_text,
        :action
      ])

  def keyword_reply_map(%KeywordReplyRule{} = rule),
    do:
      Map.take(rule, [
        :id,
        :chat_id,
        :keyword,
        :keywords,
        :match_mode,
        :case_sensitive,
        :enabled,
        :response_text,
        :buttons,
        :inserted_at,
        :updated_at
      ])

  def whitelist_rule_map(%ForbiddenWhitelistRule{} = rule),
    do: Map.take(rule, [:id, :chat_id, :word, :match_mode, :case_sensitive, :enabled])

  def moderation_event_map(%ModerationEvent{} = event) do
    Map.take(event, [
      :id,
      :chat_id,
      :message_id,
      :user_id,
      :rule_id,
      :rule_word,
      :action,
      :status,
      :details,
      :inserted_at
    ])
  end

  def schedule_map(%ScheduledMessage{} = schedule) do
    Map.take(schedule, [
      :id,
      :chat_id,
      :title,
      :text,
      :schedule_type,
      :next_run_at,
      :interval_seconds,
      :enabled,
      :preserve_first_message,
      :delete_after_seconds,
      :sent_count,
      :last_message_id,
      :last_error,
      :failure_count
    ])
  end

  defp matching_rules(chat_id) do
    Repo.all(
      from rule in ForbiddenWordRule,
        where: rule.chat_id == ^normalize_chat_id!(chat_id) and rule.enabled,
        order_by: [desc: fragment("length(?)", rule.word)]
    )
  end

  defp whitelisted?(chat_id, text) do
    Repo.all(
      from rule in ForbiddenWhitelistRule,
        where: rule.chat_id == ^normalize_chat_id!(chat_id) and rule.enabled,
        order_by: [desc: fragment("length(?)", rule.word)]
    )
    |> Enum.any?(&rule_matches?(&1, text))
  end

  defp rule_matches?(rule, text) do
    text_matches?(rule, text)
  end

  defp get_keyword_reply(chat_id, id) do
    Repo.one(
      from rule in KeywordReplyRule,
        where: rule.chat_id == ^normalize_chat_id!(chat_id) and rule.id == ^id
    )
  end

  defp recent_moderation_count(chat_id, user_id) do
    window_start = DateTime.add(DateTime.utc_now(), -86_400, :second)

    Repo.aggregate(
      from(event in ModerationEvent,
        where:
          event.chat_id == ^normalize_chat_id!(chat_id) and event.user_id == ^user_id and
            event.status == "applied" and event.inserted_at >= ^window_start
      ),
      :count,
      :id
    )
  end

  defp get_schedule(chat_id, id) do
    Repo.one(
      from schedule in ScheduledMessage,
        where: schedule.chat_id == ^normalize_chat_id!(chat_id) and schedule.id == ^id
    )
  end

  defp next_run_at(%ScheduledMessage{schedule_type: "daily", next_run_at: next_run_at}),
    do: DateTime.add(next_run_at, 86_400, :second)

  defp next_run_at(%ScheduledMessage{schedule_type: "interval", interval_seconds: seconds})
       when is_integer(seconds) and seconds >= 60,
       do: DateTime.add(DateTime.utc_now(), seconds, :second)

  defp next_run_at(_schedule), do: nil

  defp retry_delay_seconds(failure_count) when failure_count < 3, do: 60
  defp retry_delay_seconds(failure_count) when failure_count < 6, do: 300
  defp retry_delay_seconds(_failure_count), do: 1_800

  defp render_welcome(text, user) do
    username = Map.get(user, :username)
    first_name = Map.get(user, :first_name, "")
    last_name = Map.get(user, :last_name, "")
    full_name = String.trim("#{first_name} #{last_name}")

    display =
      cond do
        full_name != "" -> full_name
        is_binary(username) and username != "" -> "@#{username}"
        true -> "新成员"
      end

    text
    |> String.replace("{user}", display)
    |> String.replace("{username}", username || "")
    |> String.replace("{id}", to_string(Map.get(user, :id, "")))
  end

  defp normalize_chat_id!(chat_id) when is_integer(chat_id), do: chat_id

  defp normalize_chat_id!(chat_id) when is_binary(chat_id) do
    case Integer.parse(chat_id) do
      {id, ""} -> id
      _ -> raise ArgumentError, "invalid chat id"
    end
  end
end
