defmodule PolicrMini.Automation.LotteryDrawSnapshot do
  use PolicrMini.Schema

  @fields ~w(campaign_id entry_id user_id username display_name entry_inserted_at weight draw_order)a

  schema "lottery_draw_snapshots" do
    field :campaign_id, :integer
    field :entry_id, :integer
    field :user_id, :integer
    field :username, :string
    field :display_name, :string
    field :entry_inserted_at, :utc_datetime
    field :weight, :integer, default: 1
    field :draw_order, :integer
    timestamps(updated_at: false)
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, @fields)
    |> validate_required([:campaign_id, :entry_id, :user_id, :display_name, :entry_inserted_at, :draw_order])
    |> validate_number(:draw_order, greater_than: 0)
    |> validate_number(:weight, greater_than: 0, less_than_or_equal_to: 1000)
  end
end
