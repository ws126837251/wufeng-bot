defmodule PolicrMini.Members.ActionLog do
  @moduledoc false

  use PolicrMini.Schema

  @required_fields ~w(chat_id actor_user_id target_user_id action status)a
  @optional_fields ~w(target_display_name target_username reason telegram_error)a

  schema "member_action_logs" do
    field :chat_id, :integer
    field :actor_user_id, :integer
    field :target_user_id, :integer
    field :target_display_name, :string
    field :target_username, :string
    field :action, :string
    field :reason, :string
    field :status, :string
    field :telegram_error, :string

    timestamps(updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:action, ~w(kick unblock))
    |> validate_inclusion(:status, ~w(success failed))
    |> validate_length(:reason, max: 200)
    |> validate_length(:telegram_error, max: 1000)
  end
end
