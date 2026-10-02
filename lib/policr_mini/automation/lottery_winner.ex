defmodule PolicrMini.Automation.LotteryWinner do
  use PolicrMini.Schema

  @fields ~w(campaign_id user_id position)a

  schema "lottery_winners" do
    field :campaign_id, :integer
    field :user_id, :integer
    field :position, :integer
    timestamps(updated_at: false)
  end

  def changeset(winner, attrs) do
    winner
    |> cast(attrs, @fields)
    |> validate_required([:campaign_id, :user_id, :position])
    |> validate_number(:position, greater_than: 0)
  end
end
