defmodule PolicrMini.Repo.Migrations.CreatePrivateRelays do
  use Ecto.Migration

  def change do
    create table(:private_relays) do
      add :initiator_id, :bigint, null: false
      add :recipient_id, :bigint
      add :invite_token, :string, null: false
      add :status, :string, null: false, default: "pending"

      timestamps()
    end

    create index(:private_relays, [:invite_token])
    create index(:private_relays, [:initiator_id, :status])
    create index(:private_relays, [:recipient_id, :status])
  end
end
