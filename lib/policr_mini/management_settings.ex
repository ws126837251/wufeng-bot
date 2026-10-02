defmodule PolicrMini.ManagementSettings do
  @moduledoc false

  import Ecto.Query

  alias PolicrMini.Automation.{ChatSetting, ForbiddenWhitelistRule, ForbiddenWordRule, KeywordReplyRule}
  alias PolicrMini.Chats.{CustomKit, Scheme}
  alias PolicrMini.{Chats, Repo}

  @scheme_fields ~w(
    verification_mode
    seconds
    timeout_killing_method
    wrong_killing_method
    mention_text
    image_answers_count
    service_message_cleanup
    delay_unban_secs
  )a

  @setting_fields ~w(
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

  @forbidden_fields ~w(word match_mode case_sensitive enabled warning_text action)a
  @whitelist_fields ~w(word match_mode case_sensitive enabled)a
  @keyword_reply_fields ~w(keyword keywords match_mode case_sensitive enabled response_text buttons)a
  @custom_kit_fields ~w(title answers attachment)a

  @doc """
  Replaces the target group's configuration with configuration from the source group.
  Runtime data (members, records, lotteries, and scheduled messages) is intentionally excluded.
  """
  def copy(source_id, target_id) do
    with {:ok, source_id} <- parse_id(source_id),
         {:ok, target_id} <- parse_id(target_id),
         false <- source_id == target_id do
      Repo.transaction(fn ->
        copy_scheme!(source_id, target_id)
        copy_automation!(source_id, target_id)
        custom_kits = replace_rows!(CustomKit, source_id, target_id, @custom_kit_fields)

        %{
          verification_scheme: true,
          automation: true,
          forbidden_words: count_rows(ForbiddenWordRule, target_id),
          keyword_replies: count_rows(KeywordReplyRule, target_id),
          custom_kits: custom_kits,
          excluded: ["定时消息", "抽奖活动与参与记录", "成员、黑名单和操作记录"]
        }
      end)
    else
      true -> {:error, :same_chat}
      {:error, _} = error -> error
    end
  end

  defp copy_scheme!(source_id, target_id) do
    attrs =
      case Chats.get_scheme_by_chat_id(source_id) do
        %Scheme{} = scheme -> Map.take(scheme, @scheme_fields)
        nil -> Map.take(Scheme.default_params(), @scheme_fields)
      end

    case Chats.upsert_scheme(target_id, attrs) do
      {:ok, _scheme} -> :ok
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp copy_automation!(source_id, target_id) do
    source = Repo.get(ChatSetting, source_id) || %ChatSetting{chat_id: source_id}
    target = Repo.get(ChatSetting, target_id) || %ChatSetting{chat_id: target_id}

    case target |> ChatSetting.changeset(Map.take(source, @setting_fields)) |> Repo.insert_or_update() do
      {:ok, _setting} -> :ok
      {:error, reason} -> Repo.rollback(reason)
    end

    replace_rows!(ForbiddenWordRule, source_id, target_id, @forbidden_fields)
    replace_rows!(ForbiddenWhitelistRule, source_id, target_id, @whitelist_fields)
    replace_rows!(KeywordReplyRule, source_id, target_id, @keyword_reply_fields)
    :ok
  end

  defp replace_rows!(schema, source_id, target_id, fields) do
    source_rows = Repo.all(from row in schema, where: row.chat_id == ^source_id)
    Repo.delete_all(from row in schema, where: row.chat_id == ^target_id)

    Enum.each(source_rows, fn row ->
      attrs = row |> Map.take(fields) |> Map.put(:chat_id, target_id)

      case schema.changeset(struct(schema), attrs) |> Repo.insert() do
        {:ok, _row} -> :ok
        {:error, reason} -> Repo.rollback(reason)
      end
    end)

    length(source_rows)
  end

  defp count_rows(schema, chat_id) do
    Repo.aggregate(from(row in schema, where: row.chat_id == ^chat_id), :count, :id)
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed, ""} -> {:ok, parsed}
      _ -> {:error, :not_found}
    end
  end

  defp parse_id(_id), do: {:error, :not_found}
end
