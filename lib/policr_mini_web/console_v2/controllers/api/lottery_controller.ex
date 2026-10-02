defmodule PolicrMiniWeb.ConsoleV2.API.LotteryController do
  use PolicrMiniWeb, :controller

  alias PolicrMini.Automation.Lottery
  alias PolicrMini.Instances.Chat

  plug :ensure_access
  plug PolicrMiniWeb.ConsoleV2.ManagementApprovalGate when action in [:create, :draw, :cancel]

  def index(conn, %{"id" => chat_id}) do
    json_success(conn, Lottery.list(chat_id))
  end

  def entries(conn, %{"id" => chat_id, "lottery_id" => lottery_id}) do
    json_success(conn, Lottery.entries(chat_id, parse_id(lottery_id)))
  end

  def audit(conn, %{"id" => chat_id, "lottery_id" => lottery_id}) do
    case Lottery.audit(chat_id, parse_id(lottery_id)) do
      {:ok, audit} -> json_success(conn, audit)
      {:error, :not_found} -> json_error(conn, "Lottery not found")
    end
  end

  def create(%{assigns: %{user: user}} = conn, %{"id" => chat_id} = params) do
    case Lottery.create(chat_id, user.id, Map.drop(params, ["id"])) do
      {:ok, campaign} -> json_success(conn, Lottery.campaign_map(campaign))
      {:error, changeset} -> json_error(conn, changeset_message(changeset))
    end
  end

  def draw(conn, %{"id" => chat_id, "lottery_id" => lottery_id}) do
    case Lottery.draw_for_chat(chat_id, parse_id(lottery_id)) do
      {:ok, campaign, _winners} -> json_success(conn, Lottery.campaign_map(campaign))
      {:error, :not_found} -> json_error(conn, "Lottery not found")
      {:error, :closed} -> json_error(conn, "Lottery is already closed")
      {:error, :not_due} -> json_error(conn, "Lottery has not reached its end time")
    end
  end

  def cancel(conn, %{"id" => chat_id, "lottery_id" => lottery_id}) do
    case Lottery.cancel_for_chat(chat_id, parse_id(lottery_id)) do
      {:ok, campaign} -> json_success(conn, Lottery.campaign_map(campaign))
      {:error, :not_found} -> json_error(conn, "Lottery not found")
      {:error, :closed} -> json_error(conn, "Lottery is already closed")
    end
  end

  defp ensure_access(conn, _opts) do
    chat_id = conn.params["id"]
    user = conn.assigns[:user]
    action =
      case conn.private.phoenix_action do
        action when action in [:index, :entries, :audit] -> :show
        action when action in [:create, :draw, :cancel] -> action
      end

    with {:ok, chat} <- Chat.get(chat_id), true <- Canada.Can.can?(user, action, chat) do
      conn
    else
      _ ->
        conn
        |> put_status(:forbidden)
        |> json(%{success: false, message: "您没有该群组的操作权限"})
        |> halt()
    end
  end

  defp json_success(conn, payload), do: json(conn, %{success: true, payload: payload})

  defp json_error(conn, message) do
    conn |> put_status(:unprocessable_entity) |> json(%{success: false, message: message})
  end

  defp changeset_message(%Ecto.Changeset{} = changeset) do
    changeset.errors |> Enum.map_join("; ", fn {field, {message, _}} -> "#{field}: #{message}" end)
  end

  defp parse_id(id) when is_integer(id), do: id
  defp parse_id(id) when is_binary(id), do: String.to_integer(id)
end
