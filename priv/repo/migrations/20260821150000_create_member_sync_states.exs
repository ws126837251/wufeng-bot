defmodule PolicrMini.Repo.Migrations.CreateMemberSyncStates do
  use Ecto.Migration

  def change do
    create table(:member_sync_states, primary_key: false) do
      add :chat_id, :bigint, primary_key: true
      add :status, :string, null: false, default: "idle"
      add :telegram_count, :integer, null: false, default: 0
      add :indexed_count, :integer, null: false, default: 0
      add :last_started_at, :utc_datetime
      add :last_completed_at, :utc_datetime
      add :last_error, :text
      timestamps()
    end
  end
end
