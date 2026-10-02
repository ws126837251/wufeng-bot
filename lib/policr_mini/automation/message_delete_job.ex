defmodule PolicrMini.Automation.MessageDeleteJob do
  use PolicrMini.Schema

  @fields ~w(chat_id message_id run_at status kind attempts last_error)a

  schema "message_delete_jobs" do
    field :chat_id, :integer
    field :message_id, :integer
    field :run_at, :utc_datetime
    field :status, :string, default: "pending"
    field :kind, :string, default: "bot_message"
    field :attempts, :integer, default: 0
    field :last_error, :string
    timestamps()
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, @fields)
    |> validate_required([:chat_id, :message_id, :run_at, :status, :kind])
    |> validate_inclusion(:status, ~w(pending running completed failed))
  end
end
