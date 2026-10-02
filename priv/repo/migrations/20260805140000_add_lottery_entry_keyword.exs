defmodule PolicrMini.Repo.Migrations.AddLotteryEntryKeyword do
  use Ecto.Migration

  def change do
    alter table(:lottery_campaigns) do
      add :entry_keyword, :string
    end
  end
end
