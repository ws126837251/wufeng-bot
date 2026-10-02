defmodule PolicrMini.Repo.Migrations.CreateManagementApprovals do
  use Ecto.Migration

  def change do
    create table(:management_approvals) do
      add :chat_id, :bigint, null: false
      add :owner_user_id, :bigint, null: false
      add :requester_user_id, :bigint, null: false
      add :request_method, :string, null: false
      add :request_path, :text, null: false
      add :request_params, :map, null: false, default: %{}
      add :action_key, :string, null: false
      add :summary, :text, null: false
      add :request_fingerprint, :string, null: false
      add :callback_token, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :notification_message_id, :bigint
      add :response_status, :integer
      add :response_body, :text
      add :last_error, :text
      add :decided_at, :utc_datetime
      add :executed_at, :utc_datetime
      timestamps()
    end

    create unique_index(:management_approvals, [:callback_token])

    create unique_index(
             :management_approvals,
             [:chat_id, :requester_user_id, :request_fingerprint],
             where: "status = 'pending'",
             name: :management_approvals_pending_unique
           )

    create index(:management_approvals, [:chat_id, :status, :inserted_at])
    create index(:management_approvals, [:owner_user_id, :status, :inserted_at])
  end
end
