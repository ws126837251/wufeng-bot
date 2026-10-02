defmodule PolicrMini.Automation.HealthCheck do
  use PolicrMini.Schema

  @primary_key {:chat_id, :integer, autogenerate: false}
  @fields ~w(chat_id status missing_permissions last_error last_checked_at)a

  schema "automation_health_checks" do
    field :status, :string, default: "unknown"
    field :missing_permissions, {:array, :string}, default: []
    field :last_error, :string
    field :last_checked_at, :utc_datetime
    timestamps()
  end

  def changeset(check, attrs) do
    check
    |> cast(attrs, @fields)
    |> validate_required([:chat_id, :status, :last_checked_at])
    |> validate_inclusion(:status, ~w(healthy attention unavailable inactive unknown))
  end
end
