defmodule PolicrMini.Members.BlacklistEntry do
  @moduledoc false

  use PolicrMini.Schema

  @required_fields ~w(chat_id user_id actor_user_id active)a
  @optional_fields ~w(
    target_display_name target_username reason enforced_at last_error
    removed_by_user_id removed_at
  )a

  schema "member_blacklists" do
    field :chat_id, :integer
    field :user_id, :integer
    field :actor_user_id, :integer
    field :target_display_name, :string
    field :target_username, :string
    field :reason, :string
    field :active, :boolean, default: true
    field :enforced_at, :utc_datetime
    field :last_error, :string
    field :removed_by_user_id, :integer
    field :removed_at, :utc_datetime

    timestamps()
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:reason, max: 200)
    |> validate_length(:last_error, max: 1000)
    |> unique_constraint([:chat_id, :user_id], name: :member_blacklists_chat_user_unique)
  end
end
