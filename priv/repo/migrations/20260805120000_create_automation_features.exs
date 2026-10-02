defmodule PolicrMini.Repo.Migrations.CreateAutomationFeatures do
  use Ecto.Migration

  def change do
    create table(:chat_automation_settings, primary_key: false) do
      add :chat_id, :bigint, primary_key: true
      add :auto_delete_bot_messages, :boolean, default: false, null: false
      add :bot_message_delete_after_seconds, :integer, default: 0, null: false
      add :welcome_enabled, :boolean, default: false, null: false
      add :welcome_text, :text
      add :welcome_delete_after_seconds, :integer, default: 0, null: false
      add :forbidden_enabled, :boolean, default: false, null: false
      add :forbidden_warning_text, :text
      add :forbidden_warning_delete_after_seconds, :integer, default: 0, null: false
      timestamps()
    end

    create table(:forbidden_word_rules) do
      add :chat_id, :bigint, null: false
      add :word, :string, null: false
      add :match_mode, :string, default: "contains", null: false
      add :case_sensitive, :boolean, default: false, null: false
      add :enabled, :boolean, default: true, null: false
      add :warning_text, :text
      timestamps()
    end

    create unique_index(:forbidden_word_rules, [:chat_id, :word])
    create index(:forbidden_word_rules, [:chat_id, :enabled])

    create table(:scheduled_messages) do
      add :chat_id, :bigint, null: false
      add :title, :string, null: false
      add :text, :text, null: false
      add :schedule_type, :string, default: "one_time", null: false
      add :next_run_at, :utc_datetime, null: false
      add :interval_seconds, :integer
      add :enabled, :boolean, default: true, null: false
      add :preserve_first_message, :boolean, default: false, null: false
      add :delete_after_seconds, :integer, default: 0, null: false
      add :sent_count, :integer, default: 0, null: false
      add :last_message_id, :bigint
      timestamps()
    end

    create index(:scheduled_messages, [:chat_id, :enabled, :next_run_at])

    create table(:message_delete_jobs) do
      add :chat_id, :bigint, null: false
      add :message_id, :bigint, null: false
      add :run_at, :utc_datetime, null: false
      add :status, :string, default: "pending", null: false
      add :kind, :string, default: "bot_message", null: false
      add :attempts, :integer, default: 0, null: false
      add :last_error, :text
      timestamps()
    end

    create index(:message_delete_jobs, [:status, :run_at])
    create index(:message_delete_jobs, [:chat_id, :message_id])
  end
end
