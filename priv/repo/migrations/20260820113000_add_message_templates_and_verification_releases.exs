defmodule PolicrMini.Repo.Migrations.AddMessageTemplatesAndVerificationReleases do
  use Ecto.Migration

  def change do
    alter table(:chat_automation_settings) do
      add(:message_templates, :map, null: false, default: %{})
    end

    alter table(:verifications) do
      add(:release_action, :string)
      add(:release_at, :utc_datetime)
      add(:unbanned_at, :utc_datetime)
    end

    create(index(:verifications, [:release_at, :unbanned_at]))
  end
end
