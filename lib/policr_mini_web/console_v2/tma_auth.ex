defmodule PolicrMiniWeb.ConsoleV2.TMAAuth do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn
  import PolicrMiniWeb.ConsoleV2.ViewHelper, only: [failure: 1]

  alias PolicrMini.Accounts

  @session_cookie "wufeng_console_v2"
  @session_salt "wufeng-console-v2"
  @session_max_age 43_200
  @tma_max_age 21_600

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn = fetch_cookies(conn)

    case parse_tma(get_req_header(conn, "authorization")) do
      {:approval, token} ->
        load_approval(conn, token)

      {:ok, user_info, raw} ->
        check_tma(conn, user_info, raw)

      {:error, :missing} ->
        load_saved_or_fallback_user(conn)

      {:error, _} ->
        load_saved_or_fallback_user(conn)
    end
  end

  defp parse_tma([<<"tma " <> rest>>]) do
    with %{"user" => user_json} <- URI.decode_query(rest),
         {:ok, user_info} when is_map(user_info) <- Jason.decode(user_json) do
      {:ok, user_info, rest}
    else
      _ -> {:error, :invalid}
    end
  end

  defp parse_tma([<<"approval " <> token>>]), do: {:approval, token}

  defp parse_tma([]), do: {:error, :missing}
  defp parse_tma(_), do: {:error, :invalid}

  defp check_tma(conn, user_info, raw) when is_map(user_info) do
    case TelegramMiniappValidation.validate(raw, Telegex.Instance.token(), @tma_max_age) do
      {:ok, _} -> load_user(conn, user_info)
      {:error, _} -> load_saved_or_fallback_user(conn)
    end
  end

  defp load_user(conn, user_info) do
    id = user_info["id"]

    user =
      if user = Accounts.get_user(id) do
        user
      else
        params = %{
          username: user_info["username"],
          first_name: user_info["first_name"],
          last_name: user_info["last_name"],
          # todo: 添加 language_code 字段
          # language_code: user_info["language_code"],
          token_ver: 0
        }

        user = Accounts.upsert_user!(id, params)
        # todo: 处理头像同步的错误
        PolicrMiniBot.Helper.sync_user_photo(user)

        user
      end

    conn
    |> assign(:user, user)
    |> persist_session(user.id)
  end

  defp load_saved_or_fallback_user(conn) do
    case saved_session_user(conn) do
      nil ->
        fallback_tma_user_id =
          Application.get_env(:policr_mini, __MODULE__)[:fallback_tma_user_id]

        if user = fallback_tma_user_id && Accounts.get_user(fallback_tma_user_id) do
          assign(conn, :user, user)
        else
          resp_unauthorized(conn)
        end

      user ->
        assign(conn, :user, user)
    end
  end

  defp saved_session_user(conn) do
    with token when is_binary(token) <- conn.req_cookies[@session_cookie],
         {:ok, user_id} <- Phoenix.Token.verify(PolicrMiniWeb.Endpoint, @session_salt, token, max_age: @session_max_age),
         user when not is_nil(user) <- Accounts.get_user(user_id) do
      user
    else
      _ -> nil
    end
  end

  defp persist_session(conn, user_id) do
    token = Phoenix.Token.sign(PolicrMiniWeb.Endpoint, @session_salt, user_id)

    put_resp_cookie(conn, @session_cookie, token,
      max_age: @session_max_age,
      http_only: true,
      secure: true,
      same_site: "Lax",
      path: "/console/v2"
    )
  end

  defp load_approval(conn, token) do
    case PolicrMini.ManagementApprovals.verify_replay_authorization(token) do
      {:ok, approval, user} ->
        conn
        |> assign(:user, user)
        |> assign(:management_approval_replay, approval)

      {:error, _reason} ->
        resp_unauthorized(conn)
    end
  end

  defp resp_unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(failure("Unauthorized"))
    |> halt()
  end
end
