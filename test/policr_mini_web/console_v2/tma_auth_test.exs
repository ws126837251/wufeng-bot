defmodule PolicrMiniWeb.ConsoleV2.TMAAuthTest do
  use ExUnit.Case, async: false

  import Plug.Test

  alias PolicrMiniWeb.ConsoleV2.TMAAuth

  setup do
    previous = Application.get_env(:policr_mini, TMAAuth)
    Application.put_env(:policr_mini, TMAAuth, fallback_tma_user_id: nil)

    on_exit(fn ->
      if previous do
        Application.put_env(:policr_mini, TMAAuth, previous)
      else
        Application.delete_env(:policr_mini, TMAAuth)
      end
    end)
  end

  test "returns an object instead of a double-encoded JSON string" do
    response = conn(:get, "/") |> TMAAuth.call([])

    assert response.status == 401
    assert response.halted
    assert %{"success" => false} = Jason.decode!(response.resp_body)
  end
end
