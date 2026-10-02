defmodule PolicrMini.Repo.Migrations.CreateLotteryFeatures do
  use Ecto.Migration

  def change do
    create table(:lottery_campaigns) do
      add :chat_id, :bigint, null: false
      add :creator_id, :bigint, null: false
      add :title, :string, null: false
      add :description, :text
      add :prize, :string, null: false
      add :winner_count, :integer, null: false, default: 1
      add :end_at, :utc_datetime, null: false
      add :status, :string, null: false, default: "active"
      add :message_id, :bigint
      add :drawn_at, :utc_datetime
      timestamps()
    end

    create index(:lottery_campaigns, [:chat_id, :status, :end_at])

    create table(:lottery_entries) do
      add :campaign_id, references(:lottery_campaigns, on_delete: :delete_all), null: false
      add :user_id, :bigint, null: false
      add :username, :string
      add :display_name, :string, null: false
      timestamps(updated_at: false)
    end

    create unique_index(:lottery_entries, [:campaign_id, :user_id])
    create index(:lottery_entries, [:campaign_id])

    create table(:lottery_winners) do
      add :campaign_id, references(:lottery_campaigns, on_delete: :delete_all), null: false
      add :user_id, :bigint, null: false
      add :position, :integer, null: false
      timestamps(updated_at: false)
    end

    create unique_index(:lottery_winners, [:campaign_id, :user_id])
    create unique_index(:lottery_winners, [:campaign_id, :position])
  end
end
