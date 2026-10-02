defmodule PolicrMini.Repo.Migrations.AddModerationSafetyFeatures do
  use Ecto.Migration

  def change do
    alter table(:scheduled_messages) do
      add :last_error, :text
      add :failure_count, :integer, null: false, default: 0
    end

    alter table(:chat_automation_settings) do
      add :forbidden_escalation_enabled, :boolean, null: false, default: false
    end

    alter table(:forbidden_word_rules) do
      add :action, :string, null: false, default: "delete_warn"
    end

    create table(:forbidden_whitelist_rules) do
      add :chat_id, :bigint, null: false
      add :word, :string, null: false
      add :match_mode, :string, null: false, default: "contains"
      add :case_sensitive, :boolean, null: false, default: false
      add :enabled, :boolean, null: false, default: true
      timestamps()
    end

    create unique_index(:forbidden_whitelist_rules, [:chat_id, :word])
    create index(:forbidden_whitelist_rules, [:chat_id, :enabled])

    create table(:moderation_events) do
      add :chat_id, :bigint, null: false
      add :message_id, :bigint, null: false
      add :user_id, :bigint
      add :rule_id, references(:forbidden_word_rules, on_delete: :nilify_all)
      add :rule_word, :string, null: false
      add :action, :string, null: false
      add :status, :string, null: false, default: "applied"
      add :details, :map, null: false, default: %{}
      timestamps(updated_at: false)
    end

    create index(:moderation_events, [:chat_id, :inserted_at])
    create index(:moderation_events, [:chat_id, :user_id, :inserted_at])
  end
end
