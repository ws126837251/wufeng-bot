defmodule PolicrMini.Schema.PrivateRelay do
  @moduledoc false

  use PolicrMini.Schema

  @required_fields ~w(initiator_id invite_token status)a
  @optional_fields ~w(recipient_id)a

  schema "private_relays" do
    field :initiator_id, :integer
    field :recipient_id, :integer
    field :invite_token, :string
    field :status, :string

    timestamps()
  end

  def changeset(%__MODULE__{} = relay, attrs) when is_map(attrs) do
    relay
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:invite_token)
  end
end
