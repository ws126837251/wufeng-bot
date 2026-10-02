defmodule PolicrMini.Automation.Dispatcher do
  use GenServer

  require Logger

  alias PolicrMini.Automation

  @interval 5_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    send(self(), :tick)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:tick, state) do
    process_delete_jobs()
    process_schedules()
    process_lotteries()
    Process.send_after(self(), :tick, @interval)
    {:noreply, state}
  end

  defp process_delete_jobs do
    for job <- Automation.claim_due_delete_jobs() do
      result = delete_message_idempotently(job.chat_id, job.message_id)

      Automation.finish_delete_job(job, result)
    end
  end

  defp delete_message_idempotently(chat_id, message_id) do
    case Telegex.delete_message(chat_id, message_id) do
      {:ok, true} ->
        :ok

      {:error, %{description: description}}
      when description in [
             "Bad Request: message to delete not found",
             "Bad Request: message can't be deleted"
           ] ->
        :ok

      {:error, reason} ->
        {:error, reason}

      other ->
        {:error, other}
    end
  end

  defp process_schedules do
    for schedule <- Automation.claim_due_schedules() do
      case Automation.run_schedule(schedule) do
        {:ok, _} -> :ok
        {:error, reason} -> Logger.warning("Scheduled message failed: #{inspect(reason)}")
      end
    end
  end

  defp process_lotteries do
    for campaign <- Automation.Lottery.due() do
      case Automation.Lottery.draw(campaign.id, false) do
        {:ok, _campaign, _winners} ->
          :ok

        {:error, reason} ->
          Logger.warning("Lottery draw failed: #{inspect(reason)}", chat_id: campaign.chat_id)
      end
    end
  end
end
