defmodule PolicrMini.Repo.Migrations.AddLotteryDrawAudit do
  use Ecto.Migration

  def change do
    alter table(:lottery_campaigns) do
      add :draw_seed, :string
      add :entries_digest, :string
      add :snapshot_count, :integer, null: false, default: 0
    end

    create table(:lottery_draw_snapshots) do
      add :campaign_id, references(:lottery_campaigns, on_delete: :delete_all), null: false
      add :entry_id, :bigint, null: false
      add :user_id, :bigint, null: false
      add :username, :string
      add :display_name, :string, null: false
      add :entry_inserted_at, :utc_datetime, null: false
      add :draw_order, :integer, null: false
      timestamps(updated_at: false)
    end

    create unique_index(:lottery_draw_snapshots, [:campaign_id, :user_id])
    create unique_index(:lottery_draw_snapshots, [:campaign_id, :draw_order],
             name: :lottery_draw_snapshots_campaign_draw_order_unique
           )
  end
end
