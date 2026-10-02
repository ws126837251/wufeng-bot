defmodule PolicrMini.Repo.Migrations.AddAutomationHealthChecks do
  use Ecto.Migration

  def change do
    create table(:automation_health_checks, primary_key: false) do
      add :chat_id, :bigint, primary_key: true
      add :status, :string, null: false, default: "unknown"
      add :missing_permissions, {:array, :string}, null: false, default: []
      add :last_error, :text
      add :last_checked_at, :utc_datetime, null: false
      timestamps()
    end
  end
end
