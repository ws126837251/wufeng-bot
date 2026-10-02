defmodule PolicrMini.Repo.Migrations.AddKeywordsToKeywordReplyRules do
  use Ecto.Migration

  def up do
    alter table(:keyword_reply_rules) do
      add(:keywords, {:array, :text}, null: false, default: [])
    end

    execute("UPDATE keyword_reply_rules SET keywords = ARRAY[keyword]")

    drop_if_exists(
      index(
        :keyword_reply_rules,
        [:chat_id, :keyword, :match_mode, :case_sensitive],
        name: :keyword_reply_rules_identity_index
      )
    )

    create(
      unique_index(
        :keyword_reply_rules,
        [:chat_id, :keywords, :match_mode, :case_sensitive],
        name: :keyword_reply_rules_keywords_identity_index
      )
    )
  end

  def down do
    drop_if_exists(
      index(
        :keyword_reply_rules,
        [:chat_id, :keywords, :match_mode, :case_sensitive],
        name: :keyword_reply_rules_keywords_identity_index
      )
    )

    create(
      unique_index(
        :keyword_reply_rules,
        [:chat_id, :keyword, :match_mode, :case_sensitive],
        name: :keyword_reply_rules_identity_index
      )
    )

    alter table(:keyword_reply_rules) do
      remove(:keywords)
    end
  end
end
