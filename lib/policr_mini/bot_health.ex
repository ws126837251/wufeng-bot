defmodule PolicrMini.BotHealth do
  @moduledoc false

  alias PolicrMini.Automation
  alias PolicrMini.Automation.HealthCheck
  alias PolicrMini.Instances.Chat
  alias PolicrMini.Repo
  alias PolicrMiniBot.Heartbeat

  import PolicrMiniBot.Helper

  @critical_permissions ~w(administrator send_messages delete_messages restrict_members)

  def check(chat_id) do
    case Repo.get(Chat, chat_id) do
      nil -> {:error, :not_found}
      chat -> audit(chat)
    end
  end

  def audit(%Chat{} = chat) do
    result = inspect_permissions(chat)
    heartbeat = Heartbeat.status()
    automation = Automation.health_summary(chat.id)
    result = %{result | status: overall_status(result.status, heartbeat, automation)}
    check = persist_check(chat.id, result)

    {:ok,
     %{
       checked_at: check.last_checked_at,
       status: result.status,
       takeover: chat.is_take_over,
       bot: Map.put(heartbeat, :initialized, bot_initialized?()),
       permissions: result.permissions,
       automation: automation,
       last_audit: health_check_map(check)
     }}
  end

  defp inspect_permissions(%Chat{id: chat_id, is_take_over: is_take_over}) do
    case initialized_bot_id() do
      nil -> unavailable("机器人尚未完成初始化")
      bot_id -> inspect_member(chat_id, bot_id, is_take_over)
    end
  end

  defp inspect_member(chat_id, bot_id, is_take_over) do
    case Telegex.get_chat_member(chat_id, bot_id) do
      {:ok, member} ->
        permissions = %{
          administrator: is_administrator?(member),
          send_messages: can_send_messages?(member),
          delete_messages: can_delete_messages?(member),
          restrict_members: can_restrict_members?(member),
          pin_messages: can_pin_messages?(member)
        }

        missing =
          permissions
          |> Enum.filter(fn {_name, granted?} -> !granted? end)
          |> Enum.map(fn {name, _granted?} -> Atom.to_string(name) end)

        critical_missing = Enum.filter(missing, &(&1 in @critical_permissions))

        %{
          status: health_status(is_take_over, critical_missing),
          missing_permissions: missing,
          error: nil,
          permissions: Map.put(permissions, :member_status, Map.get(member, :status))
        }

      {:error, %Telegex.Error{description: description}} ->
        unavailable(description)

      {:error, %Telegex.RequestError{reason: :timeout}} ->
        unavailable("Telegram 权限检查超时")

      {:error, reason} ->
        unavailable("Telegram 权限检查失败：#{inspect(reason, limit: 8)}")

      other ->
        unavailable("Telegram 权限检查返回异常：#{inspect(other, limit: 8)}")
    end
  end

  defp unavailable(error) do
    %{
      status: "unavailable",
      missing_permissions: [],
      error: String.slice(to_string(error), 0, 500),
      permissions: %{
        administrator: false,
        send_messages: false,
        delete_messages: false,
        restrict_members: false,
        pin_messages: false,
        member_status: nil
      }
    }
  end

  defp health_status(false, _critical_missing), do: "inactive"
  defp health_status(true, []), do: "healthy"
  defp health_status(true, _critical_missing), do: "attention"

  @doc false
  def overall_status(permission_status, _heartbeat, _automation)
      when permission_status != "healthy",
      do: permission_status

  def overall_status("healthy", heartbeat, automation) do
    unresolved_error =
      heartbeat.last_error_at != nil and
        (heartbeat.last_success_at == nil or
           DateTime.compare(heartbeat.last_error_at, heartbeat.last_success_at) == :gt)

    automation_problem =
      automation.overdue_schedules > 0 or automation.failed_schedules > 0

    if unresolved_error or automation_problem, do: "attention", else: "healthy"
  end

  defp initialized_bot_id do
    PolicrMiniBot.id()
  rescue
    ArgumentError -> nil
  end

  defp bot_initialized? do
    PolicrMiniBot.info() != nil
  rescue
    ArgumentError -> false
  end

  defp persist_check(chat_id, result) do
    attrs = %{
      chat_id: chat_id,
      status: result.status,
      missing_permissions: result.missing_permissions,
      last_error: result.error,
      last_checked_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    %HealthCheck{}
    |> HealthCheck.changeset(attrs)
    |> Repo.insert(
      on_conflict:
        {:replace, [:status, :missing_permissions, :last_error, :last_checked_at, :updated_at]},
      conflict_target: :chat_id,
      returning: true
    )
    |> case do
      {:ok, check} -> check
      {:error, changeset} -> raise "Persist health check failed: #{inspect(changeset.errors)}"
    end
  end

  defp health_check_map(%HealthCheck{} = check) do
    Map.take(check, [:status, :missing_permissions, :last_error, :last_checked_at])
  end
end
