defmodule PolicrMiniWeb.ConsoleV2.API.VerificationView do
  use PolicrMiniWeb, :view
  use PolicrMiniWeb.ConsoleV2.Helpers, :view

  def render("show.json", %{verification: verification}) do
    success(render_one(verification, __MODULE__, "verification.json"))
  end

  def render("verification.json", %{verification: verification}) do
    %{
      id: verification.id,
      user_id: verification.target_user_id,
      user_full_name: verification.target_user_name,
      status: migrate_status(verification.status),
      source: verification.source,
      duration_secs: DateTime.diff(verification.updated_at, verification.inserted_at, :second),
      release_status: release_status(verification),
      release_at: verification.release_at,
      unbanned_at: verification.unbanned_at,
      inserted_at: verification.inserted_at,
      updated_at: verification.updated_at
    }
  end

  defp release_status(%{unbanned_at: %DateTime{}}), do: :released

  defp release_status(%{release_at: %DateTime{} = release_at}) do
    if DateTime.compare(release_at, DateTime.utc_now()) == :gt, do: :scheduled, else: :due
  end

  defp release_status(%{status: status})
       when status in [:expired, :timeout, :wronged, :manual_kick],
       do: :needs_review

  defp release_status(_verification), do: :none

  def migrate_status(status) do
    case status do
      :waiting -> :pending
      :passed -> :approved
      :wronged -> :incorrect
      other -> other
    end
  end
end
