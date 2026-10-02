defmodule PolicrMini.Repo.Migrations.CreateKeywordReplyRules do
  use Ecto.Migration

  def change do
    create table(:keyword_reply_rules) do
      add(:chat_id, :bigint, null: false)
      add(:keyword, :string, null: false)
      add(:match_mode, :string, null: false, default: "contains")
      add(:case_sensitive, :boolean, null: false, default: false)
      add(:enabled, :boolean, null: false, default: true)
      add(:response_text, :text, null: false)
      add(:buttons, {:array, :map}, null: false, default: [])
      timestamps()
    end

    create(
      unique_index(
        :keyword_reply_rules,
        [:chat_id, :keyword, :match_mode, :case_sensitive],
        name: :keyword_reply_rules_identity_index
      )
    )

    create(index(:keyword_reply_rules, [:chat_id, :enabled]))
  end
end
