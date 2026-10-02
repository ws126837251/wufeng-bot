defmodule PolicrMini.Repo.Migrations.AddLotteryEntryMessageCleanup do
  use Ecto.Migration

  def change do
    alter table(:lottery_campaigns) do
      add :auto_delete_entry_messages, :boolean, null: false, default: false
      add :entry_message_delete_after_seconds, :integer, null: false, default: 8
    end
  end
end
