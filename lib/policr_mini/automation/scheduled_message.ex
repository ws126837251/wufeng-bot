defmodule PolicrMini.Automation.ScheduledMessage do
  use PolicrMini.Schema

  @fields ~w(
    chat_id
    title
    text
    schedule_type
    next_run_at
    interval_seconds
    enabled
    preserve_first_message
    delete_after_seconds
    sent_count
    last_message_id
    last_error
    failure_count
  )a

  schema "scheduled_messages" do
    field :chat_id, :integer
    field :title, :string
    field :text, :string
    field :schedule_type, :string, default: "one_time"
    field :next_run_at, :utc_datetime
    field :interval_seconds, :integer
    field :enabled, :boolean, default: true
    field :preserve_first_message, :boolean, default: false
    field :delete_after_seconds, :integer, default: 0
    field :sent_count, :integer, default: 0
    field :last_message_id, :integer
    field :last_error, :string
    field :failure_count, :integer, default: 0
    timestamps()
  end

  def changeset(schedule, attrs) do
    schedule
    |> cast(attrs, @fields)
    |> validate_required([:chat_id, :title, :text, :schedule_type, :next_run_at])
    |> validate_inclusion(:schedule_type, ~w(one_time daily interval))
    |> validate_number(:interval_seconds, greater_than_or_equal_to: 60)
    |> validate_number(:delete_after_seconds,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 172_740
    )
  end
end
