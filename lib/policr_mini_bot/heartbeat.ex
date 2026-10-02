defmodule PolicrMiniBot.Heartbeat do
  @moduledoc false

  use GenServer

  @name __MODULE__

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  def booted, do: GenServer.cast(@name, {:touch, :booted_at})
  def updated, do: GenServer.cast(@name, {:touch, :last_update_at})
  def succeeded, do: GenServer.cast(@name, {:touch, :last_success_at})

  def failed(error) do
    GenServer.cast(@name, {:failed, summarize_error(error)})
  end

  def status do
    GenServer.call(@name, :status)
  catch
    :exit, _ -> empty_status()
  end

  @impl true
  def init(_opts) do
    {:ok, Map.put(empty_status(), :started_at, now())}
  end

  @impl true
  def handle_cast({:touch, field}, state) do
    {:noreply, Map.put(state, field, now())}
  end

  def handle_cast({:failed, error}, state) do
    {:noreply, state |> Map.put(:last_error, error) |> Map.put(:last_error_at, now())}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state, state}
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp summarize_error(error) do
    error
    |> inspect(limit: 12, printable_limit: 300)
    |> String.slice(0, 500)
  end

  defp empty_status do
    %{
      started_at: nil,
      booted_at: nil,
      last_update_at: nil,
      last_success_at: nil,
      last_error_at: nil,
      last_error: nil
    }
  end
end
