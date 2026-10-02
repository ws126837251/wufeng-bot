defmodule PolicrMini.Repo.Migrations.CreateMemberBlacklists do
  use Ecto.Migration

  def up do
    create table(:member_blacklists) do
      add :chat_id, :bigint, null: false
      add :user_id, :bigint, null: false
      add :actor_user_id, :bigint, null: false
      add :target_display_name, :string
      add :target_username, :string
      add :reason, :text
      add :active, :boolean, null: false, default: true
      add :enforced_at, :utc_datetime
      add :last_error, :text
      add :removed_by_user_id, :bigint
      add :removed_at, :utc_datetime
      timestamps()
    end

    create unique_index(:member_blacklists, [:chat_id, :user_id],
             name: :member_blacklists_chat_user_unique
           )

    create index(:member_blacklists, [:chat_id, :active, :inserted_at])
    execute(backfill_sql())
  end

  def down do
    drop table(:member_blacklists)
  end

  defp backfill_sql do
    """
    INSERT INTO member_blacklists (
      chat_id, user_id, actor_user_id, target_display_name, target_username,
      reason, active, inserted_at, updated_at
    )
    SELECT DISTINCT ON (chat_id, target_user_id)
      chat_id, target_user_id, actor_user_id, target_display_name, target_username,
      reason, TRUE, inserted_at, NOW()
    FROM member_action_logs
    WHERE action = 'kick' AND status = 'success'
    ORDER BY chat_id, target_user_id, inserted_at DESC
    ON CONFLICT (chat_id, user_id) DO NOTHING
    """
  end
end
