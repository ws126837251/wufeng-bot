defmodule PolicrMiniBot.VerificationRelease do
  @moduledoc false

  import Ecto.Query
  import PolicrMiniBot.Helper, only: [async_run: 1, async_run: 2, derestrict_chat_member: 2]

  alias PolicrMini.{Chats, Repo}
  alias PolicrMini.Chats.Verification

  require Logger

  @release_statuses [:expired, :timeout, :wronged, :manual_kick]

  def schedule(%Verification{} = verification, action, delay_seconds)
      when action in [:unban, :derestrict] and is_integer(delay_seconds) do
    delay_seconds = max(delay_seconds, 1)
    release_at = DateTime.utc_now() |> DateTime.add(delay_seconds, :second) |> truncate()

    with {:ok, verification} <-
           Chats.update_verification(verification, %{
             release_action: Atom.to_string(action),
             release_at: release_at,
             unbanned_at: nil
           }) do
      async_run(fn -> release_with_retry(verification.id, :system) end,
        delay_secs: delay_seconds
      )

      {:ok, verification}
    end
  end

  def release_now(%Verification{} = verification, role \\ :admin)
      when role in [:admin, :system] do
    action = release_action(verification)
    now = truncate(DateTime.utc_now())

    with {:ok, verification} <-
           Chats.update_verification(verification, %{
             release_action: Atom.to_string(action),
             release_at: now
           }) do
      release_with_retry(verification.id, role)
    end
  end

  def recover_due do
    now = truncate(DateTime.utc_now())

    from(v in Verification,
      where: v.status in ^@release_statuses and is_nil(v.unbanned_at),
      order_by: [asc: v.inserted_at],
      limit: 500,
      preload: [:operations]
    )
    |> Repo.all()
    |> Enum.map(&recover_candidate(&1, now))
  end

  def release_with_retry(verification_id, role, attempts \\ 3)

  def release_with_retry(verification_id, role, attempts) when attempts > 0 do
    verification = Repo.get!(Verification, verification_id)

    if verification.unbanned_at do
      {:ok, verification}
    else
      case release_member(verification) do
        {:ok, true} ->
          mark_released(verification, role)

        error when attempts > 1 ->
          Logger.warning(
            "Verification release failed; retrying: #{inspect(verification_id: verification.id, attempts_left: attempts - 1, reason: error)}"
          )

          Process.sleep(1_000)
          release_with_retry(verification_id, role, attempts - 1)

        error ->
          Logger.error(
            "Verification release failed after retries: #{inspect(verification_id: verification.id, reason: error)}"
          )

          error
      end
    end
  end

  defp recover_candidate(%{release_at: %DateTime{} = release_at} = verification, now) do
    if DateTime.compare(release_at, now) in [:lt, :eq] do
      release_with_retry(verification.id, :system)
    else
      :pending
    end
  end

  defp recover_candidate(%{release_at: nil} = verification, now) do
    case legacy_release_action(verification) do
      nil ->
        :ignored

      action ->
        scheme = Chats.find_or_init_scheme!(verification.chat_id)
        delay_seconds = scheme.delay_unban_secs || 300
        release_at = verification.updated_at |> DateTime.add(delay_seconds, :second) |> truncate()
        release_at = if verification.status == :expired, do: now, else: release_at

        {:ok, verification} =
          Chats.update_verification(verification, %{
            release_action: Atom.to_string(action),
            release_at: release_at
          })

        recover_candidate(verification, now)
    end
  end

  defp legacy_release_action(%{status: :expired, source: :joined}), do: :derestrict
  defp legacy_release_action(%{status: :expired}), do: :unban
  defp legacy_release_action(%{status: :manual_kick}), do: :unban

  defp legacy_release_action(%{operations: operations}) do
    sorter = fn left, right -> DateTime.compare(left, right) != :lt end

    case Enum.max_by(operations, & &1.inserted_at, sorter, fn -> nil end) do
      %{action: :kick} -> :unban
      %{action: :unban} -> :unban
      _ -> nil
    end
  end

  defp release_member(verification) do
    case release_action(verification) do
      :derestrict -> derestrict_chat_member(verification.chat_id, verification.target_user_id)
      :unban -> Telegex.unban_chat_member(verification.chat_id, verification.target_user_id)
    end
  end

  defp release_action(%{release_action: "derestrict"}), do: :derestrict
  defp release_action(%{release_action: "unban"}), do: :unban
  defp release_action(%{status: :expired, source: :joined}), do: :derestrict
  defp release_action(_verification), do: :unban

  defp mark_released(verification, role) do
    now = truncate(DateTime.utc_now())

    case Repo.update_all(
           from(v in Verification,
             where: v.id == ^verification.id and is_nil(v.unbanned_at)
           ),
           set: [unbanned_at: now, updated_at: now]
         ) do
      {1, _} ->
        create_operation(verification, role)
        {:ok, Repo.get!(Verification, verification.id)}

      {0, _} ->
        {:ok, Repo.get!(Verification, verification.id)}
    end
  end

  defp create_operation(verification, role) do
    case Chats.create_operation(%{
           chat_id: verification.chat_id,
           verification_id: verification.id,
           action: :unban,
           role: role
         }) do
      {:ok, _operation} -> :ok
      {:error, reason} -> Logger.warning("Create release operation failed: #{inspect(reason)}")
    end
  end

  defp truncate(datetime), do: DateTime.truncate(datetime, :second)
end
