defmodule PolicrMini.PrivateRelays do
  @moduledoc false

  import Ecto.Query, only: [from: 2]

  alias PolicrMini.Repo
  alias PolicrMini.Schema.PrivateRelay

  @active_status "active"
  @pending_status "pending"
  @closed_status "closed"
  @public_status "public"
  @public_token "public"

  def ensure_public_gateway(owner_id) when is_integer(owner_id) do
    case Repo.one(
           from r in PrivateRelay,
             where:
               r.initiator_id == ^owner_id and is_nil(r.recipient_id) and
                 r.invite_token == ^@public_token,
             limit: 1
         ) do
      nil ->
        %PrivateRelay{}
        |> PrivateRelay.changeset(%{
          initiator_id: owner_id,
          invite_token: @public_token,
          status: @public_status
        })
        |> Repo.insert()

      _relay ->
        :ok
    end
  end

  def ensure_public_gateway(_owner_id), do: :ok

  def enable_public(owner_id) when is_integer(owner_id) do
    Repo.transaction(fn ->
      relay =
        Repo.one(
          from r in PrivateRelay,
            where:
              r.initiator_id == ^owner_id and is_nil(r.recipient_id) and
                r.invite_token == ^@public_token,
            limit: 1,
            lock: "FOR UPDATE"
        )

      case relay do
        nil ->
          %PrivateRelay{}
          |> PrivateRelay.changeset(%{
            initiator_id: owner_id,
            invite_token: @public_token,
            status: @public_status
          })
          |> Repo.insert!()

        relay ->
          relay
          |> Ecto.Changeset.change(status: @public_status)
          |> Repo.update!()
      end
    end)
  end

  def disable_public(owner_id) when is_integer(owner_id) do
    from(r in PrivateRelay,
      where:
        r.initiator_id == ^owner_id and is_nil(r.recipient_id) and
          r.invite_token == ^@public_token
    )
    |> Repo.update_all(set: [status: @closed_status, updated_at: DateTime.utc_now()])
  end

  def accept_public(recipient_id) when is_integer(recipient_id) do
    owner_id = PolicrMiniBot.config_get(:owner_id)

    Repo.transaction(fn ->
      gateway =
        Repo.one(
          from r in PrivateRelay,
            where:
              r.initiator_id == ^owner_id and r.invite_token == ^@public_token and
                is_nil(r.recipient_id) and
                r.status == ^@public_status,
            limit: 1,
            lock: "FOR UPDATE"
        )

      cond do
        not is_integer(owner_id) or gateway == nil -> Repo.rollback(:unavailable)
        owner_id == recipient_id -> Repo.rollback(:self)
        true ->
          close_for(recipient_id)

          %PrivateRelay{}
          |> PrivateRelay.changeset(%{
            initiator_id: owner_id,
            recipient_id: recipient_id,
            invite_token: @public_token,
            status: @active_status
          })
          |> Repo.insert!()
      end
    end)
  end

  def create_invite(user_id) when is_integer(user_id) do
    Repo.transaction(fn ->
      close_pending_for(user_id)

      %PrivateRelay{}
      |> PrivateRelay.changeset(%{
        initiator_id: user_id,
        invite_token: invite_token(),
        status: @pending_status
      })
      |> Repo.insert!()
    end)
  end

  def accept_invite(token, recipient_id) when is_binary(token) and is_integer(recipient_id) do
    if token == @public_token do
      accept_public(recipient_id)
    else
      accept_invite_token(token, recipient_id)
    end
  end

  defp accept_invite_token(token, recipient_id) do
    Repo.transaction(fn ->
      relay =
        Repo.one(
          from r in PrivateRelay,
            where: r.invite_token == ^token and r.status == ^@pending_status,
            lock: "FOR UPDATE"
        )

      cond do
        relay == nil -> Repo.rollback(:not_found)
        relay.status != @pending_status -> Repo.rollback(:unavailable)
        relay.initiator_id == recipient_id -> Repo.rollback(:self)
        true ->
          close_for(recipient_id)

          %PrivateRelay{}
          |> PrivateRelay.changeset(%{
            initiator_id: relay.initiator_id,
            recipient_id: recipient_id,
            invite_token: relay.invite_token,
            status: @active_status
          })
          |> Repo.insert!()
      end
    end)
  end

  def active_for(user_id) when is_integer(user_id) do
    Repo.one(
      from r in PrivateRelay,
        where: r.status == ^@active_status and r.recipient_id == ^user_id,
        order_by: [desc: r.updated_at],
        limit: 1
    )
  end

  def close_pending_for(user_id) when is_integer(user_id) do
    from(r in PrivateRelay,
      where: r.status == ^@pending_status and r.initiator_id == ^user_id
    )
    |> Repo.update_all(set: [status: @closed_status, updated_at: DateTime.utc_now()])
  end

  def peer_id(%PrivateRelay{initiator_id: initiator_id, recipient_id: recipient_id}, initiator_id),
    do: recipient_id

  def peer_id(%PrivateRelay{initiator_id: initiator_id}, _user_id) when is_integer(initiator_id),
    do: initiator_id

  def close_for(user_id) when is_integer(user_id) do
    from(r in PrivateRelay,
      where:
        r.status in [^@pending_status, ^@active_status] and
          (r.initiator_id == ^user_id or r.recipient_id == ^user_id)
    )
    |> Repo.update_all(set: [status: @closed_status, updated_at: DateTime.utc_now()])
  end

  defp invite_token do
    :crypto.strong_rand_bytes(18) |> Base.url_encode64(padding: false)
  end
end
