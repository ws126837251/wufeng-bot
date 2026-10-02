defmodule PolicrMini.ManagementApproval do
  @moduledoc false

  use PolicrMini.Schema

  @required_fields ~w(
    chat_id owner_user_id requester_user_id request_method request_path request_params
    action_key summary request_fingerprint callback_token status
  )a
  @optional_fields ~w(
    notification_message_id response_status response_body last_error decided_at executed_at
  )a

  schema "management_approvals" do
    field :chat_id, :integer
    field :owner_user_id, :integer
    field :requester_user_id, :integer
    field :request_method, :string
    field :request_path, :string
    field :request_params, :map, default: %{}
    field :action_key, :string
    field :summary, :string
    field :request_fingerprint, :string
    field :callback_token, :string
    field :status, :string, default: "pending"
    field :notification_message_id, :integer
    field :response_status, :integer
    field :response_body, :string
    field :last_error, :string
    field :decided_at, :utc_datetime
    field :executed_at, :utc_datetime
    timestamps()
  end

  def changeset(approval, attrs) do
    approval
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, ~w(pending executing approved rejected failed))
    |> unique_constraint(:callback_token)
    |> unique_constraint([:chat_id, :requester_user_id, :request_fingerprint],
      name: :management_approvals_pending_unique,
      error_key: :request_fingerprint
    )
  end
end
