defmodule PolicrMini.Automation.LotteryReferral do
  use PolicrMini.Schema

  @fields ~w(campaign_id chat_id inviter_id invitee_id invitee_name invitee_username status completed_at)a

  schema "lottery_referrals" do
    field :campaign_id, :integer
    field :chat_id, :integer
    field :inviter_id, :integer
    field :invitee_id, :integer
    field :invitee_name, :string
    field :invitee_username, :string
    field :status, :string, default: "pending"
    field :completed_at, :utc_datetime
    timestamps()
  end

  def changeset(referral, attrs) do
    referral
    |> cast(attrs, @fields)
    |> validate_required([:campaign_id, :chat_id, :inviter_id, :invitee_id])
    |> validate_number(:campaign_id, greater_than: 0)
    |> validate_number(:chat_id, less_than: 0)
    |> validate_number(:inviter_id, greater_than: 0)
    |> validate_number(:invitee_id, greater_than: 0)
    |> validate_inclusion(:status, ~w(pending completed rejected))
  end
end
