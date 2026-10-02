defmodule PolicrMiniBot.RespStatusChain do
  @moduledoc "群内检查机器人及管理权限的命令。"

  use PolicrMiniBot.Chain, {:command, :status}

  alias PolicrMini.Automation.MessageTemplates
  alias PolicrMini.BotHealth

  @group_types ["group", "supergroup"]

  @impl true
  def handle(
        %{chat: %{id: chat_id, type: type}, message_id: message_id},
        %{from_admin: true} = context
      )
      when type in @group_types do
    case BotHealth.check(chat_id) do
      {:ok, health} ->
        send_text(chat_id, status_text(chat_id, health),
          reply_to_message_id: message_id,
          auto_delete_after: 30,
          logging: true
        )

      {:error, _reason} ->
        send_text(chat_id, MessageTemplates.render(chat_id, :status_failed),
          reply_to_message_id: message_id,
          auto_delete_after: 8,
          logging: true
        )
    end

    async_delete_message(chat_id, message_id)
    {:stop, %{context | deleted: true}}
  end

  def handle(%{chat: %{id: chat_id}, message_id: message_id}, context) do
    send_text(chat_id, MessageTemplates.render(chat_id, :status_admin_only),
      reply_to_message_id: message_id,
      auto_delete_after: 8,
      logging: true
    )

    async_delete_message(chat_id, message_id)
    {:stop, %{context | deleted: true}}
  end

  @doc false
  def status_text(health) do
    MessageTemplates.render_template(
      MessageTemplates.defaults()["status_body"],
      status_bindings(health)
    )
  end

  defp status_text(chat_id, health) do
    MessageTemplates.render(chat_id, :status_body, status_bindings(health))
  end

  defp status_bindings(health) do
    permissions = health.permissions

    %{
      status: status_label(health.status),
      takeover: enabled_label(health.takeover),
      administrator: permission_label(permissions.administrator),
      send_messages: permission_label(permissions.send_messages),
      delete_messages: permission_label(permissions.delete_messages),
      restrict_members: permission_label(permissions.restrict_members),
      pin_messages: permission_label(permissions.pin_messages)
    }
  end

  defp status_label("healthy"), do: "正常 ✅"
  defp status_label("attention"), do: "需要检查 ⚠️"
  defp status_label("inactive"), do: "未接管 ⏸️"
  defp status_label(_status), do: "暂不可用 ❌"

  defp enabled_label(true), do: "已开启 ✅"
  defp enabled_label(false), do: "未开启 ⏸️"
  defp permission_label(true), do: "正常 ✅"
  defp permission_label(false), do: "缺失 ❌"
end
