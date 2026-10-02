defmodule PolicrMini.Automation.LotteryCampaign do
  use PolicrMini.Schema

  @fields ~w(chat_id creator_id title description prize winner_count end_at entry_keyword enable_referrals mention_all pin_message auto_delete_entry_messages entry_message_delete_after_seconds status message_id drawn_at draw_seed entries_digest draw_algorithm snapshot_count)a

  schema "lottery_campaigns" do
    field :chat_id, :integer
    field :creator_id, :integer
    field :title, :string
    field :description, :string
    field :prize, :string
    field :winner_count, :integer, default: 1
    field :end_at, :utc_datetime
    field :entry_keyword, :string
    field :enable_referrals, :boolean, default: true
    field :mention_all, :boolean, default: false
    field :pin_message, :boolean, default: false
    field :auto_delete_entry_messages, :boolean, default: false
    field :entry_message_delete_after_seconds, :integer, default: 8
    field :status, :string, default: "active"
    field :message_id, :integer
    field :drawn_at, :utc_datetime
    field :draw_seed, :string
    field :entries_digest, :string
    field :draw_algorithm, :string
    field :snapshot_count, :integer, default: 0
    timestamps()
  end

  def changeset(campaign, attrs) do
    campaign
    |> cast(attrs, @fields)
    |> validate_required([:chat_id, :creator_id, :title, :prize, :winner_count, :end_at])
    |> validate_length(:title, min: 1, max: 120)
    |> validate_length(:prize, min: 1, max: 300)
    |> validate_length(:entry_keyword, max: 80)
    |> validate_number(:winner_count, greater_than: 0, less_than_or_equal_to: 100)
    |> validate_number(:entry_message_delete_after_seconds,
      greater_than: 0,
      less_than_or_equal_to: 172_740
    )
    |> validate_inclusion(:status, ~w(active drawn canceled))
  end
end
