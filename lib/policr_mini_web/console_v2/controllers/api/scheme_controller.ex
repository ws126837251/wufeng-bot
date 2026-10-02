defmodule PolicrMiniWeb.ConsoleV2.API.SchemeController do
  use PolicrMiniWeb, :controller

  alias PolicrMini.Chats
  alias PolicrMini.Chats.Scheme

  import Canary.Plugs

  plug :authorize_resource, model: Scheme
  plug PolicrMiniWeb.ConsoleV2.ManagementApprovalGate when action in [:update]

  def update(conn, %{"id" => id} = params) do
    # 接收新版本参数并转换到旧版本
    params = Scheme.cast_from_new_params(params)

    with {:ok, scheme} <- Chats.load_scheme(id),
         {:ok, scheme} <- Chats.update_scheme(scheme, params) do
      render(conn, "show.json", scheme: scheme)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, message: changeset_message(changeset)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, message: "验证方案不存在"})
    end
  end

  defp changeset_message(%Ecto.Changeset{errors: errors}) do
    Enum.map_join(errors, "；", fn
      {:seconds, _} -> "验证超时时间不合法"
      {:delay_unban_secs, _} -> "解封延时必须为45秒以上"
      {field, {message, _}} -> "#{field}: #{message}"
    end)
  end
end
