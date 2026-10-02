defmodule PolicrMini.Repo.Migrations.AllowPrivateRelayInviteReuse do
  use Ecto.Migration

  def up do
    drop_if_exists(index(:private_relays, [:invite_token], name: :private_relays_invite_token_index))
    create index(:private_relays, [:invite_token])
  end

  def down do
    drop_if_exists(index(:private_relays, [:invite_token], name: :private_relays_invite_token_index))
    create unique_index(:private_relays, [:invite_token])
  end
end
