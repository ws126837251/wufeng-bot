defmodule PolicrMiniWeb.ConsoleV2.API.AutomationController do
  use PolicrMiniWeb, :controller

  alias PolicrMini.Automation
  alias PolicrMini.Instances.Chat

  import Canary.Plugs

  plug :authorize_resource, model: Chat
  plug PolicrMiniWeb.ConsoleV2.ManagementApprovalGate

  def show(conn, %{"id" => chat_id}) do
    json_success(conn, Automation.settings_map(Automation.get_settings!(chat_id)))
  end

  def update(conn, %{"id" => chat_id} = params) do
    case Automation.update_settings(chat_id, Map.drop(params, ["id"])) do
      {:ok, setting} -> json_success(conn, Automation.settings_map(setting))
      {:error, changeset} -> json_error(conn, changeset_message(changeset))
    end
  end

  def forbidden_words(conn, %{"id" => chat_id}) do
    payload = Enum.map(Automation.list_forbidden_words(chat_id), &Automation.rule_map/1)
    json_success(conn, payload)
  end

  def add_forbidden_word(conn, %{"id" => chat_id} = params) do
    case Automation.create_forbidden_word(chat_id, Map.drop(params, ["id"])) do
      {:ok, rule} -> json_success(conn, Automation.rule_map(rule))
      {:error, changeset} -> json_error(conn, changeset_message(changeset))
    end
  end

  def delete_forbidden_word(conn, %{"id" => chat_id, "word_id" => id}) do
    case Automation.delete_forbidden_word(chat_id, parse_id(id)) do
      {:ok, rule} -> json_success(conn, Automation.rule_map(rule))
      {:error, :not_found} -> json_error(conn, "Forbidden word not found")
    end
  end

  def keyword_replies(conn, %{"id" => chat_id}) do
    payload = Enum.map(Automation.list_keyword_replies(chat_id), &Automation.keyword_reply_map/1)
    json_success(conn, payload)
  end

  def add_keyword_reply(conn, %{"id" => chat_id} = params) do
    case Automation.create_keyword_reply(chat_id, Map.drop(params, ["id"])) do
      {:ok, rule} -> json_success(conn, Automation.keyword_reply_map(rule))
      {:error, changeset} -> json_error(conn, changeset_message(changeset))
    end
  end

  def update_keyword_reply(conn, %{"id" => chat_id, "reply_id" => id} = params) do
    attrs = Map.drop(params, ["id", "reply_id"])

    case Automation.update_keyword_reply(chat_id, parse_id(id), attrs) do
      {:ok, rule} -> json_success(conn, Automation.keyword_reply_map(rule))
      {:error, :not_found} -> json_error(conn, "Keyword reply rule not found")
      {:error, changeset} -> json_error(conn, changeset_message(changeset))
    end
  end

  def delete_keyword_reply(conn, %{"id" => chat_id, "reply_id" => id}) do
    case Automation.delete_keyword_reply(chat_id, parse_id(id)) do
      {:ok, rule} -> json_success(conn, Automation.keyword_reply_map(rule))
      {:error, :not_found} -> json_error(conn, "Keyword reply rule not found")
    end
  end

  def forbidden_whitelist(conn, %{"id" => chat_id}) do
    payload =
      Enum.map(Automation.list_forbidden_whitelist(chat_id), &Automation.whitelist_rule_map/1)

    json_success(conn, payload)
  end

  def add_forbidden_whitelist(conn, %{"id" => chat_id} = params) do
    case Automation.create_forbidden_whitelist_rule(chat_id, Map.drop(params, ["id"])) do
      {:ok, rule} -> json_success(conn, Automation.whitelist_rule_map(rule))
      {:error, changeset} -> json_error(conn, changeset_message(changeset))
    end
  end

  def delete_forbidden_whitelist(conn, %{"id" => chat_id, "rule_id" => id}) do
    case Automation.delete_forbidden_whitelist_rule(chat_id, parse_id(id)) do
      {:ok, rule} -> json_success(conn, Automation.whitelist_rule_map(rule))
      {:error, :not_found} -> json_error(conn, "Whitelist rule not found")
    end
  end

  def moderation_events(conn, %{"id" => chat_id}) do
    payload =
      Enum.map(Automation.list_moderation_events(chat_id), &Automation.moderation_event_map/1)

    json_success(conn, payload)
  end

  def schedules(conn, %{"id" => chat_id}) do
    payload = Enum.map(Automation.list_schedules(chat_id), &Automation.schedule_map/1)
    json_success(conn, payload)
  end

  def add_schedule(conn, %{"id" => chat_id} = params) do
    case Automation.create_schedule(chat_id, Map.drop(params, ["id"])) do
      {:ok, schedule} -> json_success(conn, Automation.schedule_map(schedule))
      {:error, changeset} -> json_error(conn, changeset_message(changeset))
    end
  end

  def update_schedule(conn, %{"id" => chat_id, "schedule_id" => id} = params) do
    attrs = Map.drop(params, ["id", "schedule_id"])

    case Automation.update_schedule(chat_id, parse_id(id), attrs) do
      {:ok, schedule} -> json_success(conn, Automation.schedule_map(schedule))
      {:error, :not_found} -> json_error(conn, "Scheduled message not found")
      {:error, changeset} -> json_error(conn, changeset_message(changeset))
    end
  end

  def test_schedule(conn, %{"id" => chat_id, "schedule_id" => id}) do
    case Automation.test_schedule(chat_id, parse_id(id)) do
      {:ok, schedule, message} ->
        payload =
          schedule
          |> Automation.schedule_map()
          |> Map.put(:test_message_id, message.message_id)

        json_success(conn, payload)

      {:error, :not_found} ->
        json_error(conn, "Scheduled message not found")

      {:error, reason} ->
        json_error(conn, "Test message failed: #{inspect(reason)}")
    end
  end

  def delete_schedule(conn, %{"id" => chat_id, "schedule_id" => id}) do
    case Automation.delete_schedule(chat_id, parse_id(id)) do
      {:ok, schedule} -> json_success(conn, Automation.schedule_map(schedule))
      {:error, :not_found} -> json_error(conn, "Scheduled message not found")
    end
  end

  defp json_success(conn, payload), do: json(conn, %{success: true, payload: payload})

  defp json_error(conn, message) do
    conn |> put_status(:unprocessable_entity) |> json(%{success: false, message: message})
  end

  defp changeset_message(%Ecto.Changeset{} = changeset) do
    changeset.errors
    |> Enum.map_join("; ", fn {field, {message, _}} -> "#{field}: #{message}" end)
  end

  defp parse_id(id) when is_integer(id), do: id
  defp parse_id(id) when is_binary(id), do: String.to_integer(id)
end
