defmodule PolicrMini.BotHealthTest do
  use ExUnit.Case, async: true

  alias PolicrMini.BotHealth

  @automation %{overdue_schedules: 0, failed_schedules: 0}

  test "reports attention for an unresolved polling error" do
    now = DateTime.utc_now()
    heartbeat = %{last_error_at: now, last_success_at: DateTime.add(now, -1, :second)}

    assert BotHealth.overall_status("healthy", heartbeat, @automation) == "attention"
  end

  test "returns to healthy after a successful update" do
    now = DateTime.utc_now()
    heartbeat = %{last_error_at: now, last_success_at: DateTime.add(now, 1, :second)}

    assert BotHealth.overall_status("healthy", heartbeat, @automation) == "healthy"
  end
end
