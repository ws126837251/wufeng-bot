defmodule PolicrMini.Repo.Migrations.CreateGroupMemberManagement do
  use Ecto.Migration

  def up do
    create table(:group_members) do
      add :chat_id, :bigint, null: false
      add :user_id, :bigint, null: false
      add :status, :string, null: false, default: "unknown"
      add :source, :string, null: false, default: "observed"
      add :is_bot, :boolean, null: false, default: false
      timestamps()
    end

    create unique_index(:group_members, [:chat_id, :user_id],
             name: :group_members_chat_user_unique
           )

    create index(:group_members, [:chat_id, :inserted_at])

    create table(:member_action_logs) do
      add :chat_id, :bigint, null: false
      add :actor_user_id, :bigint, null: false
      add :target_user_id, :bigint, null: false
      add :target_display_name, :string
      add :target_username, :string
      add :action, :string, null: false
      add :reason, :text
      add :status, :string, null: false
      add :telegram_error, :text
      timestamps(updated_at: false)
    end

    create index(:member_action_logs, [:chat_id, :inserted_at])
    create index(:member_action_logs, [:chat_id, :target_user_id])

    execute(backfill_users_sql())
    execute(backfill_members_sql())
  end

  def down do
    drop table(:member_action_logs)
    drop table(:group_members)
  end

  defp backfill_users_sql do
    """
    INSERT INTO users (id, first_name, username, token_ver, inserted_at, updated_at)
    SELECT DISTINCT ON (user_id) user_id, display_name, username, 0, NOW(), NOW()
    FROM (
      SELECT target_user_id AS user_id, target_user_name AS display_name, NULL::varchar AS username
      FROM verifications
      WHERE target_user_id IS NOT NULL
      UNION ALL
      SELECT user_id, display_name, username
      FROM lottery_entries
      WHERE user_id IS NOT NULL
    ) known_users
    ORDER BY user_id
    ON CONFLICT (id) DO NOTHING
    """
  end

  defp backfill_members_sql do
    """
    INSERT INTO group_members (chat_id, user_id, status, source, is_bot, inserted_at, updated_at)
    SELECT DISTINCT ON (chat_id, user_id)
      chat_id, user_id, 'unknown', source, false, first_seen_at, first_seen_at
    FROM (
      SELECT chat_id, user_id, 'administrator' AS source, inserted_at AS first_seen_at
      FROM permissions
      UNION ALL
      SELECT chat_id, target_user_id AS user_id, 'verification' AS source, inserted_at AS first_seen_at
      FROM verifications
      WHERE target_user_id IS NOT NULL
      UNION ALL
      SELECT c.chat_id, e.user_id, 'lottery' AS source, e.inserted_at AS first_seen_at
      FROM lottery_entries e
      JOIN lottery_campaigns c ON c.id = e.campaign_id
    ) known_members
    ORDER BY chat_id, user_id, first_seen_at
    ON CONFLICT (chat_id, user_id) DO NOTHING
    """
  end
end
