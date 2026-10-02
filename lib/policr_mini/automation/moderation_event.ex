defmodule PolicrMini.Automation.ModerationEvent do
  use PolicrMini.Schema

  @fields ~w(chat_id message_id user_id rule_id rule_word action status details)a

  schema "moderation_events" do
    field :chat_id, :integer
    field :message_id, :integer
    field :user_id, :integer
    field :rule_id, :integer
    field :rule_word, :string
    field :action, :string
    field :status, :string, default: "applied"
    field :details, :map, default: %{}
    timestamps(updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, @fields)
    |> validate_required([:chat_id, :message_id, :rule_word, :action, :status])
    |> validate_inclusion(:action, ~w(delete_warn mute_10m mute_1h ban))
    |> validate_inclusion(:status, ~w(applied failed skipped))
  end
end
