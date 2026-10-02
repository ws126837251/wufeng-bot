defmodule PolicrMini.Repo.Migrations.AddLotteryPublishOptions do
  use Ecto.Migration

  def change do
    alter table(:lottery_campaigns) do
      add :mention_all, :boolean, null: false, default: false
      add :pin_message, :boolean, null: false, default: false
    end
  end
end
