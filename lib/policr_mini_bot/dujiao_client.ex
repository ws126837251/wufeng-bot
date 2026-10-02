defmodule PolicrMiniBot.DujiaoClient do
  @moduledoc false

  use GenServer

  require Logger

  @config_path "/api/v1/channel/telegram/config"
  @heartbeat_path "/api/v1/channel/telegram/heartbeat"
  @default_interval_ms 30_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = config()

    if enabled?(state) do
      send(self(), :sync)
    else
      Logger.info("Dujiao Telegram Bot integration disabled (missing configuration)")
    end

    {:ok, Map.put(state, :last_connected, false)}
  end

  @impl true
  def handle_info(:sync, state) do
    case sync(state) do
      {:ok, config_version} ->
        log_connection_change(state.last_connected, true, config_version)
        PolicrMiniBot.Heartbeat.succeeded()
        schedule_next(state.interval_ms)
        {:noreply, %{state | last_connected: true}}

      {:error, reason} ->
        log_connection_change(state.last_connected, false, reason)
        PolicrMiniBot.Heartbeat.failed(reason)
        schedule_next(state.interval_ms)
        {:noreply, %{state | last_connected: false}}
    end
  end

  defp sync(state) do
    with {:ok, config_version, bot_config} <- fetch_config(state),
         :ok <- send_heartbeat(state, bot_config) do
      {:ok, config_version}
    end
  end

  defp fetch_config(state) do
    case request(state, "GET", @config_path, "") do
      {:ok, 200, body} ->
        case Jason.decode(body) do
          {:ok, %{"data" => %{"config_version" => version, "config" => config}}}
               when is_integer(version) and is_map(config) ->
            {:ok, version, config}

          _ ->
            {:error, :invalid_config_response}
        end

      {:ok, status, _body} ->
        {:error, {:config_http_status, status}}

      {:error, reason} ->
        {:error, {:config_request_failed, reason}}
    end
  end

  defp send_heartbeat(state, bot_config) do
    body =
      Jason.encode!(%{
        "bot_version" => state.bot_version,
        "webhook_status" => "polling",
        "machine_code" => state.machine_code,
        "license_status" => license_status(bot_config),
        "license_expires_at" => "",
        "warnings" => []
      })

    case request(state, "POST", @heartbeat_path, body) do
      {:ok, status, _response_body} when status in 200..299 -> :ok
      {:ok, status, _response_body} -> {:error, {:heartbeat_http_status, status}}
      {:error, reason} -> {:error, {:heartbeat_request_failed, reason}}
    end
  end

  defp request(state, method, path, body) do
    timestamp = System.system_time(:second) |> Integer.to_string()
    headers = signed_headers(state.channel_key, state.channel_secret, method, path, timestamp, body)

    request = Finch.build(method, state.base_url <> path, headers, body)

    case Finch.request(request, PolicrMini.Finch) do
      {:ok, %Finch.Response{status: status, body: response_body}} ->
        {:ok, status, response_body}

      {:error, _reason} ->
        {:error, :transport_error}
    end
  end

  defp signed_headers(channel_key, channel_secret, method, path, timestamp, body) do
    body_md5 = :crypto.hash(:md5, body) |> Base.encode16(case: :lower)
    canonical = Enum.join([method, path, timestamp, body_md5], "\n")
    signature = :crypto.mac(:hmac, :sha256, channel_secret, canonical) |> Base.encode16(case: :lower)

    [
      {"content-type", "application/json"},
      {"Dujiao-Next-Channel-Key", channel_key},
      {"Dujiao-Next-Channel-Timestamp", timestamp},
      {"Dujiao-Next-Channel-Signature", signature}
    ]
  end

  defp config do
    configured = Application.get_env(:policr_mini, __MODULE__, [])

    %{
      base_url: configured[:base_url] |> to_string() |> String.trim_trailing("/"),
      channel_key: configured[:channel_key] |> to_string(),
      channel_secret: configured[:channel_secret] |> to_string(),
      interval_ms: configured[:interval_ms] || @default_interval_ms,
      bot_version: configured[:bot_version] || "wufeng-bot",
      machine_code: configured[:machine_code] || machine_code()
    }
  end

  defp enabled?(state) do
    state.base_url != "" and state.channel_key != "" and state.channel_secret != ""
  end

  defp license_status(%{"enabled" => true}), do: "configured"
  defp license_status(_), do: "disabled"

  defp machine_code do
    source = System.get_env("POLICR_MINI_DUJIAO_MACHINE_CODE") || Atom.to_string(node())

    :crypto.hash(:sha256, source)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  defp schedule_next(interval_ms), do: Process.send_after(self(), :sync, interval_ms)

  defp log_connection_change(previous, current, config_version) when previous != current do
    if current do
      Logger.info("Dujiao Telegram Bot connected (config_version=#{config_version})")
    else
      Logger.warning("Dujiao Telegram Bot disconnected: #{inspect(config_version)}")
    end
  end

  defp log_connection_change(_previous, _current, _detail), do: :ok
end
