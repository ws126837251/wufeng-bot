defmodule PolicrMini.Automation.ForbiddenWordRule do
  use PolicrMini.Schema

  @fields ~w(chat_id word match_mode case_sensitive enabled warning_text action)a

  schema "forbidden_word_rules" do
    field :chat_id, :integer
    field :word, :string
    field :match_mode, :string, default: "contains"
    field :case_sensitive, :boolean, default: false
    field :enabled, :boolean, default: true
    field :warning_text, :string
    field :action, :string, default: "delete_warn"
    timestamps()
  end

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, @fields)
    |> validate_required([:chat_id, :word])
    |> update_change(:word, &String.trim/1)
    |> validate_length(:word, min: 1, max: 200)
    |> validate_inclusion(:match_mode, ~w(contains exact prefix))
    |> validate_inclusion(:action, ~w(delete_warn mute_10m mute_1h ban))
  end
end
