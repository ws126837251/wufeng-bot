defmodule PolicrMini.Members.SyncState do
  @moduledoc false

  use PolicrMini.Schema

  @primary_key {:chat_id, :integer, autogenerate: false}
  schema "member_sync_states" do
    field :status, :string, default: "idle"
    field :telegram_count, :integer, default: 0
    field :indexed_count, :integer, default: 0
    field :last_started_at, :utc_datetime
    field :last_completed_at, :utc_datetime
    field :last_error, :string

    timestamps()
  end

  def changeset(state, attrs) do
    state
    |> cast(attrs, [
      :chat_id,
      :status,
      :telegram_count,
      :indexed_count,
      :last_started_at,
      :last_completed_at,
      :last_error
    ])
    |> validate_required([:chat_id, :status])
    |> validate_inclusion(:status, ~w(idle running success failed))
  end
end
