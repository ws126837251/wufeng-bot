defmodule PolicrMini.Repo.Migrations.CreateLotteryReferrals do
  use Ecto.Migration

  def change do
    alter table(:lottery_entries) do
      add :weight, :integer, null: false, default: 1
    end

    alter table(:lottery_draw_snapshots) do
      add :weight, :integer, null: false, default: 1
    end

    alter table(:lottery_campaigns) do
      add :draw_algorithm, :string
      add :enable_referrals, :boolean, null: false, default: true
    end

    create table(:lottery_referrals) do
      add :campaign_id, references(:lottery_campaigns, on_delete: :delete_all), null: false
      add :chat_id, :bigint, null: false
      add :inviter_id, :bigint, null: false
      add :invitee_id, :bigint, null: false
      add :invitee_name, :string
      add :invitee_username, :string
      add :status, :string, null: false, default: "pending"
      add :completed_at, :utc_datetime
      timestamps()
    end

    create unique_index(:lottery_referrals, [:campaign_id, :invitee_id],
             name: :lottery_referrals_campaign_invitee_unique
           )

    create index(:lottery_referrals, [:chat_id, :invitee_id, :status])
    create index(:lottery_referrals, [:campaign_id, :inviter_id, :status])
  end
end
