defmodule PolicrMini.Automation.LotteryEntry do
  use PolicrMini.Schema

  @fields ~w(campaign_id user_id username display_name weight)a

  schema "lottery_entries" do
    field :campaign_id, :integer
    field :user_id, :integer
    field :username, :string
    field :display_name, :string
    field :weight, :integer, default: 1
    timestamps(updated_at: false)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, @fields)
    |> validate_required([:campaign_id, :user_id, :display_name])
    |> validate_length(:display_name, min: 1, max: 160)
    |> validate_number(:weight, greater_than: 0, less_than_or_equal_to: 1000)
  end
end
