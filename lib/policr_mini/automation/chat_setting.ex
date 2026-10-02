defmodule PolicrMini.Automation.ChatSetting do
  use PolicrMini.Schema

  @primary_key {:chat_id, :integer, autogenerate: false}

  @fields ~w(
    auto_delete_bot_messages
    bot_message_delete_after_seconds
    welcome_enabled
    welcome_text
    welcome_delete_after_seconds
    forbidden_enabled
    forbidden_escalation_enabled
    forbidden_warning_text
    forbidden_warning_delete_after_seconds
    message_templates
  )a

  schema "chat_automation_settings" do
    field :auto_delete_bot_messages, :boolean, default: false
    field :bot_message_delete_after_seconds, :integer, default: 0
    field :welcome_enabled, :boolean, default: false
    field :welcome_text, :string
    field :welcome_delete_after_seconds, :integer, default: 0
    field :forbidden_enabled, :boolean, default: false
    field :forbidden_escalation_enabled, :boolean, default: false
    field :forbidden_warning_text, :string
    field :forbidden_warning_delete_after_seconds, :integer, default: 0
    field :message_templates, :map, default: %{}
    timestamps()
  end

  def changeset(setting, attrs) do
    attrs = normalize_message_templates(attrs)

    setting
    |> cast(attrs, @fields)
    |> validate_number(:bot_message_delete_after_seconds,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 172_740
    )
    |> validate_number(:welcome_delete_after_seconds,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 172_740
    )
    |> validate_number(:forbidden_warning_delete_after_seconds,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 172_740
    )
    |> validate_change(:message_templates, fn :message_templates, templates ->
      if valid_message_templates?(templates),
        do: [],
        else: [
          message_templates: "must contain only known string templates up to 2000 characters"
        ]
    end)
  end

  defp normalize_message_templates(attrs) when is_map(attrs) do
    cond do
      Map.has_key?(attrs, :message_templates) ->
        Map.update!(
          attrs,
          :message_templates,
          &PolicrMini.Automation.MessageTemplates.normalize_keys/1
        )

      Map.has_key?(attrs, "message_templates") ->
        Map.update!(
          attrs,
          "message_templates",
          &PolicrMini.Automation.MessageTemplates.normalize_keys/1
        )

      true ->
        attrs
    end
  end

  defp normalize_message_templates(attrs), do: attrs

  defp valid_message_templates?(templates) when is_map(templates) do
    allowed_keys = Map.keys(PolicrMini.Automation.MessageTemplates.defaults()) |> MapSet.new()

    Enum.all?(templates, fn {key, value} ->
      is_binary(key) and MapSet.member?(allowed_keys, key) and is_binary(value) and
        String.length(value) <= 2_000
    end)
  end

  defp valid_message_templates?(_templates), do: false
end
