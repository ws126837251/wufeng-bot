defmodule PolicrMini.Automation.Lottery do
  import Ecto.Query

  require Logger

  alias PolicrMini.Automation.{
    LotteryCampaign,
    LotteryDrawSnapshot,
    LotteryEntry,
    LotteryReferral,
    LotteryWinner,
    MessageTemplates
  }

  alias PolicrMini.{Instances, Repo}
  alias PolicrMini.Instances.Chat
  alias Telegex.Type.{InlineKeyboardButton, InlineKeyboardMarkup}

  @referral_prefix "invlt"
  @referral_bonus_weight 1

  def list(chat_id) do
    campaigns =
      Repo.all(
        from campaign in LotteryCampaign,
          where: campaign.chat_id == ^normalize_chat_id!(chat_id),
          order_by: [desc: campaign.inserted_at],
          limit: 50
      )

    Enum.map(campaigns, &campaign_map/1)
  end

  def entries(chat_id, campaign_id) do
    campaign = Repo.get(LotteryCampaign, campaign_id)

    if campaign && campaign.chat_id == normalize_chat_id!(chat_id) do
      from(entry in LotteryEntry,
        where: entry.campaign_id == ^campaign.id,
        order_by: [asc: entry.inserted_at, asc: entry.id]
      )
      |> Repo.all()
      |> Enum.map(&entry_map/1)
    else
      []
    end
  end

  @doc """
  生成抽奖邀请深链接。

  Telegram 的 `/start` 参数只允许短字符串，因此只编码活动 ID 和邀请人 ID，
  具体的群组和抽奖信息由数据库根据活动 ID 读取。
  """
  @spec referral_link(integer, integer) :: String.t()
  def referral_link(campaign_id, inviter_id) do
    "https://t.me/#{PolicrMiniBot.username()}?start=#{@referral_prefix}_#{campaign_id}_#{inviter_id}"
  end

  @doc """
  读取邀请活动信息，并构造邀请链接和目标群组链接。
  只有已经报名当前活动的用户才能生成有效邀请入口。
  """
  @spec referral_prompt(integer, integer) ::
          {:ok, map}
          | {:error,
             :not_found
             | :closed
             | :referrals_disabled
             | :inviter_not_joined
             | :group_link_unavailable}
  def referral_prompt(campaign_id, inviter_id) do
    case Repo.get(LotteryCampaign, campaign_id) do
      %LotteryCampaign{status: "active"} = campaign ->
        cond do
          not referrals_enabled?(campaign) ->
            {:error, :referrals_disabled}

          DateTime.compare(campaign.end_at, DateTime.utc_now()) != :gt ->
            {:error, :closed}

          not entry_exists?(campaign.id, inviter_id) ->
            {:error, :inviter_not_joined}

          true ->
            case campaign_group_link(campaign) do
              group_link when is_binary(group_link) and group_link != "" ->
                {:ok,
                 %{
                   campaign: campaign,
                   link: referral_link(campaign.id, inviter_id),
                   group_link: group_link
                 }}

              _ ->
                {:error, :group_link_unavailable}
            end
        end

      %LotteryCampaign{} ->
        {:error, :closed}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  记录好友打开邀请深链接后的待验证关系。

  只有已经报名当前活动的邀请人才能获得奖励，且同一活动中同一被邀请人只计数一次。
  """
  @spec register_referral(integer, integer, map) ::
          {:ok, LotteryCampaign.t(), :created | :pending | :completed}
          | {:error,
             :not_found
             | :closed
             | :referrals_disabled
             | :self
             | :inviter_not_joined
             | any}
  def register_referral(campaign_id, inviter_id, %{id: invitee_id} = invitee)
      when is_integer(campaign_id) and is_integer(inviter_id) and is_integer(invitee_id) do
    cond do
      inviter_id == invitee_id ->
        {:error, :self}

      true ->
        Repo.transaction(fn ->
          campaign =
            Repo.one(
              from(campaign in LotteryCampaign,
                where: campaign.id == ^campaign_id,
                lock: "FOR UPDATE"
              )
            )

          cond do
            campaign == nil ->
              Repo.rollback(:not_found)

            campaign.status != "active" or
                DateTime.compare(campaign.end_at, DateTime.utc_now()) != :gt ->
              Repo.rollback(:closed)

            not referrals_enabled?(campaign) ->
              Repo.rollback(:referrals_disabled)

            not entry_exists?(campaign.id, inviter_id) ->
              Repo.rollback(:inviter_not_joined)

            true ->
              case Repo.get_by(LotteryReferral,
                     campaign_id: campaign.id,
                     invitee_id: invitee_id
                   ) do
                %LotteryReferral{status: "completed"} ->
                  {campaign, :completed}

                %LotteryReferral{status: "rejected"} = referral ->
                  case referral
                       |> LotteryReferral.changeset(%{inviter_id: inviter_id, status: "pending"})
                       |> Repo.update() do
                    {:ok, _} ->
                      {campaign, :created}

                    {:error, reason} ->
                      Repo.rollback(reason)
                  end

                %LotteryReferral{} ->
                  {campaign, :pending}

                nil ->
                  params = %{
                    campaign_id: campaign.id,
                    chat_id: campaign.chat_id,
                    inviter_id: inviter_id,
                    invitee_id: invitee_id,
                    invitee_name: invitee_name(invitee),
                    invitee_username: Map.get(invitee, :username),
                    status: "pending"
                  }

                  case %LotteryReferral{}
                       |> LotteryReferral.changeset(params)
                       |> Repo.insert(
                         on_conflict: :nothing,
                         conflict_target: [:campaign_id, :invitee_id]
                       ) do
                    {:ok, %LotteryReferral{id: id}} when is_integer(id) ->
                      {campaign, :created}

                    {:ok, _} ->
                      {campaign, :pending}

                    {:error, reason} ->
                      Repo.rollback(reason)
                  end
              end
          end
        end)
        |> case do
          {:ok, {campaign, status}} -> {:ok, campaign, status}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def register_referral(_campaign_id, _inviter_id, _invitee), do: {:error, :invalid}

  @doc """
  好友通过目标群组验证后完成邀请，并为邀请人的报名记录增加一个抽奖权重。
  """
  @spec complete_referrals(integer, integer) :: {:ok, non_neg_integer()} | {:error, any}
  def complete_referrals(chat_id, invitee_id)
      when is_integer(chat_id) and is_integer(invitee_id) do
    now = DateTime.utc_now()

    result =
      Repo.transaction(fn ->
        referrals =
          Repo.all(
            from(referral in LotteryReferral,
              join: campaign in LotteryCampaign,
              on: campaign.id == referral.campaign_id,
              where:
                referral.chat_id == ^chat_id and
                  referral.invitee_id == ^invitee_id and
                  referral.status == "pending" and
                  campaign.status == "active" and
                  campaign.enable_referrals == true and
                  campaign.end_at > ^now,
              lock: "FOR UPDATE",
              select: {referral, campaign}
            )
          )

        Enum.reduce(referrals, [], fn {referral, campaign}, completed ->
          case Repo.one(
                 from(entry in LotteryEntry,
                   where:
                     entry.campaign_id == ^referral.campaign_id and
                       entry.user_id == ^referral.inviter_id,
                   lock: "FOR UPDATE"
                 )
               ) do
            %LotteryEntry{} = entry ->
              {:ok, _referral} =
                referral
                |> LotteryReferral.changeset(%{status: "completed", completed_at: now})
                |> Repo.update()

              new_weight = min((entry.weight || 1) + @referral_bonus_weight, 1_000)

              {1, _} =
                Repo.update_all(
                  from(entry in LotteryEntry,
                    where:
                      entry.campaign_id == ^referral.campaign_id and
                        entry.user_id == ^referral.inviter_id
                  ),
                  set: [weight: new_weight]
                )

              [%{campaign: campaign, referral: referral, weight: new_weight} | completed]

            nil ->
              # 邀请人已经退出报名时，不再增加任何权重。
              {:ok, _referral} =
                referral
                |> LotteryReferral.changeset(%{status: "rejected"})
                |> Repo.update()

              completed
          end
        end)
      end)

    case result do
      {:ok, completed} ->
        Enum.each(completed, &notify_referrer/1)
        {:ok, length(completed)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def complete_referrals(_chat_id, _invitee_id), do: {:ok, 0}

  @doc """
  给刚报名的用户发送邀请入口。用户尚未启动机器人时，Telegram 会返回 403，
  此时不影响正常报名，群内抽奖消息仍会保留邀请按钮。
  """
  @spec send_referral_prompt(integer, map) :: {:ok, any} | {:error, any}
  def send_referral_prompt(campaign_id, %{id: user_id}) when is_integer(user_id) do
    with {:ok, payload} <- referral_prompt(campaign_id, user_id) do
      Telegex.send_message(
        user_id,
        MessageTemplates.render(payload.campaign.chat_id, :lottery_invite_prompt, %{
          title: payload.campaign.title,
          link: payload.link,
          group: campaign_group_title(payload.campaign)
        }),
        reply_markup: referral_markup(payload),
        disable_web_page_preview: true
      )
    end
  end

  def send_referral_prompt(_campaign_id, _user), do: {:error, :invalid}

  @doc false
  def send_referral_prompt_for_chat(chat_id, %{id: user_id} = user) when is_integer(user_id) do
    campaign =
      Repo.one(
        from(campaign in LotteryCampaign,
          join: entry in LotteryEntry,
          on: entry.campaign_id == campaign.id,
          where:
            campaign.chat_id == ^normalize_chat_id!(chat_id) and
              campaign.status == "active" and
              campaign.end_at > ^DateTime.utc_now() and
              entry.user_id == ^user_id,
          order_by: [desc: campaign.inserted_at],
          limit: 1
        )
      )

    if campaign, do: send_referral_prompt(campaign.id, user), else: {:error, :not_found}
  end

  def send_referral_prompt_for_chat(_chat_id, _user), do: {:error, :invalid}

  @doc false
  def send_referral_prompt_for_keyword(chat_id, message_id, user, text)
      when is_binary(text) and (is_integer(message_id) or is_nil(message_id)) do
    campaign =
      if is_integer(message_id) do
        Repo.one(
          from(campaign in LotteryCampaign,
            where:
              campaign.chat_id == ^normalize_chat_id!(chat_id) and
                campaign.message_id == ^message_id and
                campaign.status == "active"
          )
        )
      else
        campaigns =
          Repo.all(
            from(campaign in LotteryCampaign,
              where:
                campaign.chat_id == ^normalize_chat_id!(chat_id) and
                  campaign.status == "active" and
                  campaign.end_at > ^DateTime.utc_now() and
                  not is_nil(campaign.entry_keyword),
              order_by: [desc: campaign.inserted_at],
              limit: 50
            )
          )

        case matching_keyword_campaigns(campaigns, text) do
          [campaign] -> campaign
          _ -> nil
        end
      end

    if campaign, do: send_referral_prompt(campaign.id, user), else: {:error, :not_found}
  end

  def send_referral_prompt_for_keyword(_chat_id, _message_id, _user, _text), do: {:error, :invalid}

  @doc false
  def referral_markup(%{campaign: campaign, link: link, group_link: group_link}) do
    share_text = "邀请你参加抽奖：#{campaign.title}"
    share_url = "https://t.me/share/url?#{URI.encode_query(url: link, text: share_text)}"

    rows = [
      [%InlineKeyboardButton{text: "📤 分享邀请链接", url: share_url}]
    ]

    rows =
      if is_binary(group_link) and group_link != "" do
        rows ++ [[%InlineKeyboardButton{text: "👥 打开群组", url: group_link}]]
      else
        rows
      end

    %InlineKeyboardMarkup{inline_keyboard: rows}
  end

  @doc false
  def referral_message(%{campaign: campaign, link: link}, :inviter) do
    MessageTemplates.render(campaign.chat_id, :lottery_invite_prompt, %{
      title: campaign.title,
      link: link,
      group: campaign_group_title(campaign)
    })
  end

  def referral_message(%{campaign: campaign}, :invitee) do
    MessageTemplates.render(campaign.chat_id, :lottery_referral_join_prompt, %{
      group: campaign_group_title(campaign)
    })
  end

  def audit(chat_id, campaign_id) do
    with %LotteryCampaign{} = campaign <- campaign_for(chat_id, campaign_id) do
      snapshots =
        Repo.all(
          from(snapshot in LotteryDrawSnapshot,
            where: snapshot.campaign_id == ^campaign.id,
            order_by: [asc: snapshot.draw_order]
          )
        )

      {:ok,
       %{
         campaign: campaign_map(campaign),
         proof: proof_map(campaign),
         winners: winner_maps(campaign, snapshots),
         snapshot: Enum.map(snapshots, &snapshot_map/1)
       }}
    else
      nil -> {:error, :not_found}
    end
  end

  def create(chat_id, creator_id, attrs) do
    enable_referrals =
      case Map.get(attrs, "enable_referrals", Map.get(attrs, :enable_referrals, true)) do
        nil -> true
        value -> truthy?(value)
      end
    mention_all = truthy?(Map.get(attrs, "mention_all"))
    pin_message = truthy?(Map.get(attrs, "pin_message"))
    auto_delete_entry_messages = truthy?(Map.get(attrs, "auto_delete_entry_messages"))

    attrs =
      attrs
      |> Map.put("enable_referrals", enable_referrals)
      |> Map.put("mention_all", mention_all)
      |> Map.put("pin_message", pin_message)
      |> Map.put("auto_delete_entry_messages", auto_delete_entry_messages)
      |> Map.put("chat_id", normalize_chat_id!(chat_id))
      |> Map.put("creator_id", creator_id)
      |> Map.put_new("status", "active")
      |> Map.update("entry_keyword", nil, &normalize_keyword/1)

    %LotteryCampaign{}
    |> LotteryCampaign.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, campaign} -> publish(campaign, mention_all: mention_all, pin_message: pin_message)
      error -> error
    end
  end

  def join_by_keyword(chat_id, message_id, user, text)
      when is_integer(message_id) and is_binary(text) do
    campaign =
      Repo.one(
        from campaign in LotteryCampaign,
          where:
            campaign.chat_id == ^normalize_chat_id!(chat_id) and
              campaign.message_id == ^message_id and campaign.status == "active"
      )

    cond do
      campaign == nil or blank?(campaign.entry_keyword) ->
        :ignore

      keyword_matches?(campaign.entry_keyword, text) ->
        join_by_keyword_campaign(campaign, user)

      true ->
        {:error, :keyword_mismatch, campaign.entry_keyword}
    end
  end

  def join_by_keyword(chat_id, nil, user, text) when is_binary(text) do
    campaigns =
      Repo.all(
        from campaign in LotteryCampaign,
          where:
            campaign.chat_id == ^normalize_chat_id!(chat_id) and
              campaign.status == "active" and
              campaign.end_at > ^DateTime.utc_now() and
              not is_nil(campaign.entry_keyword),
          order_by: [desc: campaign.inserted_at],
          limit: 50
      )

    case matching_keyword_campaigns(campaigns, text) do
      [campaign] -> join_by_keyword_campaign(campaign, user)
      [] -> :ignore
      _campaigns -> {:error, :ambiguous_keyword}
    end
  end

  def join_by_keyword(_chat_id, _message_id, _user, _text), do: :ignore

  @doc false
  def entry_message_delete_delay(%LotteryCampaign{
        auto_delete_entry_messages: true,
        entry_message_delete_after_seconds: seconds
      })
      when is_integer(seconds) and seconds > 0,
      do: min(seconds, 172_740)

  def entry_message_delete_delay(_campaign), do: nil

  @doc false
  def matching_keyword_campaigns(campaigns, text)
      when is_list(campaigns) and is_binary(text) do
    Enum.filter(campaigns, fn campaign ->
      keyword_matches?(Map.get(campaign, :entry_keyword), text)
    end)
  end

  def matching_keyword_campaigns(_campaigns, _text), do: []

  @doc false
  def keyword_matches?(expected, actual) when is_binary(expected) and is_binary(actual) do
    normalize_keyword_text(expected) == normalize_keyword_text(actual)
  end

  def keyword_matches?(_expected, _actual), do: false

  def draw_latest(chat_id) do
    campaign = latest_active(chat_id)

    if campaign do
      draw(campaign.id, true)
    else
      {:error, :not_found}
    end
  end

  def latest_active(chat_id) do
    Repo.one(
      from campaign in LotteryCampaign,
        where: campaign.chat_id == ^normalize_chat_id!(chat_id) and campaign.status == "active",
        order_by: [desc: campaign.inserted_at],
        limit: 1
    )
  end

  def join(campaign_id, user) do
    Repo.transaction(fn ->
      campaign =
        Repo.one(
          from(campaign in LotteryCampaign,
            where: campaign.id == ^campaign_id,
            lock: "FOR UPDATE"
          )
        )

      cond do
        campaign == nil ->
          Repo.rollback(:not_found)

        campaign.status != "active" or
            DateTime.compare(campaign.end_at, DateTime.utc_now()) != :gt ->
          Repo.rollback(:closed)

        true ->
          case insert_entry(campaign, user) do
            {:ok, row} -> {count_entries(campaign.id), row.id != nil}
            {:error, reason} -> Repo.rollback(reason)
          end
      end
    end)
    |> case do
      {:ok, {count, created?}} -> {:ok, count, created?}
      {:error, reason} -> {:error, reason}
    end
  end

  def join_for_chat(chat_id, campaign_id, user) do
    if campaign_for(chat_id, campaign_id) do
      join(campaign_id, user)
    else
      {:error, :not_found}
    end
  end

  def refresh_message(campaign_id) do
    case Repo.get(LotteryCampaign, campaign_id) do
      %LotteryCampaign{status: "active", message_id: message_id} = campaign
      when is_integer(message_id) ->
        count = count_entries(campaign.id)

        Telegex.edit_message_text(render_campaign(campaign, count),
          chat_id: campaign.chat_id,
          message_id: message_id,
          parse_mode: "HTML",
          reply_markup: markup(campaign.id, count)
        )

      _ ->
        :ok
    end
  end

  def draw(campaign_id, force? \\ true) do
    result =
      Repo.transaction(fn ->
        case Repo.one(
               from campaign in LotteryCampaign,
                 where: campaign.id == ^campaign_id,
                 lock: "FOR UPDATE"
             ) do
          nil ->
            Repo.rollback(:not_found)

          %LotteryCampaign{status: status} when status != "active" ->
            Repo.rollback(:closed)

          campaign ->
            if not force? and DateTime.compare(campaign.end_at, DateTime.utc_now()) == :gt do
              Repo.rollback(:not_due)
            else
              entries = list_entries_for_drawing(campaign.id)
              seed = draw_seed()
              ordered_entries = deterministic_order(entries, seed)

              winners =
                Enum.take(ordered_entries, min(campaign.winner_count, length(ordered_entries)))

              persist_snapshot!(campaign.id, ordered_entries)

              Enum.with_index(winners, 1)
              |> Enum.each(fn {entry, position} ->
                %LotteryWinner{}
                |> LotteryWinner.changeset(%{
                  campaign_id: campaign.id,
                  user_id: entry.user_id,
                  position: position
                })
                |> Repo.insert!()
              end)

              {:ok, campaign} =
                campaign
                |> LotteryCampaign.changeset(%{
                  status: "drawn",
                  drawn_at: DateTime.utc_now(),
                  draw_seed: seed,
                  entries_digest: entries_digest(entries),
                  draw_algorithm: "weighted_v2",
                  snapshot_count: length(ordered_entries)
                })
                |> Repo.update()

              {campaign, winners}
            end
        end
      end)

    case result do
      {:ok, {campaign, winners}} ->
        announce_result(campaign, winners)
        {:ok, campaign, winners}

      error ->
        error
    end
  end

  def draw_for_chat(chat_id, campaign_id) do
    if campaign_for(chat_id, campaign_id), do: draw(campaign_id), else: {:error, :not_found}
  end

  def cancel(campaign_id) do
    case Repo.get(LotteryCampaign, campaign_id) do
      nil ->
        {:error, :not_found}

      %LotteryCampaign{status: "active"} = campaign ->
        campaign |> LotteryCampaign.changeset(%{status: "canceled"}) |> Repo.update()

      _ ->
        {:error, :closed}
    end
  end

  def cancel_for_chat(chat_id, campaign_id) do
    if campaign_for(chat_id, campaign_id), do: cancel(campaign_id), else: {:error, :not_found}
  end

  def due do
    Repo.all(
      from campaign in LotteryCampaign,
        where: campaign.status == "active" and campaign.end_at <= ^DateTime.utc_now(),
        order_by: [asc: campaign.end_at],
        limit: 20
    )
  end

  def campaign_map(%LotteryCampaign{} = campaign) do
    Map.merge(
      Map.take(campaign, [
        :id,
        :chat_id,
        :creator_id,
        :title,
        :description,
        :prize,
        :winner_count,
        :entry_keyword,
        :enable_referrals,
        :mention_all,
        :pin_message,
        :auto_delete_entry_messages,
        :entry_message_delete_after_seconds,
        :end_at,
        :status,
        :message_id,
        :drawn_at,
        :draw_seed,
        :entries_digest,
        :draw_algorithm,
        :snapshot_count
      ]),
      %{participant_count: count_entries(campaign.id)}
    )
  end

  defp publish(campaign, options) do
    case PolicrMiniBot.MessageCaller.send_text(campaign.chat_id, render_campaign(campaign, 0),
           reply_markup: markup(campaign.id, 0),
           parse_mode: "HTML",
           disable_notification: false,
           auto_delete: false,
           logging: true
         ) do
      {:ok, %{message_id: message_id}} ->
        case campaign |> LotteryCampaign.changeset(%{message_id: message_id}) |> Repo.update() do
          {:ok, campaign} ->
            maybe_pin(campaign.chat_id, message_id, Keyword.get(options, :pin_message, false))
            {:ok, campaign}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        Repo.delete(campaign)
        {:error, reason}
    end
  end

  defp announce_result(campaign, winners) do
    text = render_result(campaign, winners)

    if is_integer(campaign.message_id) do
      Telegex.edit_message_text(text,
        chat_id: campaign.chat_id,
        message_id: campaign.message_id,
        parse_mode: "HTML"
      )
    end

    PolicrMiniBot.MessageCaller.send_text(campaign.chat_id, text,
      auto_delete: false,
      disable_notification: false,
      parse_mode: "HTML",
      logging: true
    )
  end

  defp render_campaign(campaign, count) do
    mention = if campaign.mention_all, do: "📢 @全体成员\n", else: ""

    description =
      if blank?(campaign.description), do: "", else: "\n#{escape(campaign.description)}"

    keyword =
      if blank?(campaign.entry_keyword),
        do: "",
        else: "\n回复关键词：#{escape(campaign.entry_keyword)} 即可参加"

    MessageTemplates.render(campaign.chat_id, :lottery_campaign, %{
      mention: mention,
      title: escape(campaign.title),
      prize: escape(campaign.prize),
      count: count,
      end_at: Calendar.strftime(campaign.end_at, "%Y-%m-%d %H:%M UTC"),
      keyword: keyword,
      description: description
    })
  end

  defp render_result(campaign, winners) do
    names =
      case winners do
        [] ->
          MessageTemplates.render(campaign.chat_id, :lottery_result_empty)

        list ->
          Enum.with_index(list, 1)
          |> Enum.map_join("\n", fn {entry, index} ->
            "#{index}. #{escape(entry.display_name)}"
          end)
      end

    MessageTemplates.render(campaign.chat_id, :lottery_result, %{
      title: escape(campaign.title),
      prize: escape(campaign.prize),
      winners: names
    })
  end

  defp markup(campaign_id, count) do
    campaign = Repo.get!(LotteryCampaign, campaign_id)
    invite_button = %{
      text: "🎁 邀请好友提高中奖率",
      callback_data: "lottery:v1:invite:#{campaign_id}"
    }

    base_rows =
      if blank?(campaign.entry_keyword) do
        [
          [
            %InlineKeyboardButton{
              text: "🎁 立即参加（#{count}人）",
              callback_data: "lottery:v1:join:#{campaign_id}"
            }
          ]
        ]
      else
        [
          [
            %{
              text: "📋 点击复制关键词：#{campaign.entry_keyword}",
              copy_text: %{text: campaign.entry_keyword}
            }
          ]
        ]
      end

    rows = if referrals_enabled?(campaign), do: base_rows ++ [[invite_button]], else: base_rows

    %InlineKeyboardMarkup{inline_keyboard: rows}
  end

  defp count_entries(campaign_id),
    do:
      Repo.aggregate(
        from(entry in LotteryEntry, where: entry.campaign_id == ^campaign_id),
        :count,
        :id
      )

  defp join_by_keyword_campaign(campaign, user) do
    case join(campaign.id, user) do
      {:ok, count, created?} ->
        {:ok, count, created?, entry_message_delete_delay(campaign)}

      error ->
        error
    end
  end

  defp campaign_for(chat_id, campaign_id) do
    Repo.one(
      from(campaign in LotteryCampaign,
        where: campaign.id == ^campaign_id and campaign.chat_id == ^normalize_chat_id!(chat_id)
      )
    )
  end

  defp insert_entry(campaign, user) do
    %LotteryEntry{}
    |> LotteryEntry.changeset(%{
      campaign_id: campaign.id,
      user_id: Map.get(user, :id),
      username: Map.get(user, :username),
      display_name: display_name(user)
    })
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:campaign_id, :user_id])
  end

  defp list_entries_for_drawing(campaign_id) do
    Repo.all(
      from(entry in LotteryEntry,
        where: entry.campaign_id == ^campaign_id,
        order_by: [asc: entry.inserted_at, asc: entry.id]
      )
    )
  end

  defp draw_seed do
    :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)
  end

  defp deterministic_order(entries, seed) do
    Enum.sort_by(entries, fn entry ->
      {weighted_score(entry, seed), entry.id}
    end)
  end

  defp weighted_score(entry, seed) do
    1..max(entry.weight || 1, 1)
    |> Enum.map(fn ticket ->
      :crypto.hash(
        :sha256,
        "#{seed}:#{entry.id}:#{entry.user_id}:#{DateTime.to_iso8601(entry.inserted_at)}:#{ticket}"
      )
    end)
    |> Enum.min()
  end

  defp entries_digest(entries) do
    entries
    |> Enum.map(fn entry ->
      [
        entry.id,
        entry.user_id,
        entry.username,
        entry.display_name,
        entry.weight || 1,
        DateTime.to_iso8601(entry.inserted_at)
      ]
    end)
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp persist_snapshot!(campaign_id, entries) do
    entries
    |> Enum.with_index(1)
    |> Enum.each(fn {entry, draw_order} ->
      %LotteryDrawSnapshot{}
      |> LotteryDrawSnapshot.changeset(%{
        campaign_id: campaign_id,
        entry_id: entry.id,
        user_id: entry.user_id,
        username: entry.username,
        display_name: entry.display_name,
        entry_inserted_at: entry.inserted_at,
        weight: entry.weight || 1,
        draw_order: draw_order
      })
      |> Repo.insert!()
    end)
  end

  defp proof_map(%LotteryCampaign{} = campaign) do
    if campaign.status == "drawn" and is_binary(campaign.draw_seed) do
      %{
        available: true,
        algorithm: proof_algorithm(campaign),
        seed: campaign.draw_seed,
        entries_digest: campaign.entries_digest,
        snapshot_count: campaign.snapshot_count
      }
    else
      %{available: false}
    end
  end

  defp proof_algorithm(%LotteryCampaign{draw_algorithm: "weighted_v2"}),
    do: "每个报名按权重生成 SHA-256(ticket) 分数，按最低分升序取前 N 位"

  defp proof_algorithm(%LotteryCampaign{}),
    do: "旧版活动使用未启用邀请权重的 SHA-256 排序；可通过种子与摘要复核"

  defp winner_maps(campaign, snapshots) do
    positions =
      Repo.all(
        from(winner in LotteryWinner,
          where: winner.campaign_id == ^campaign.id,
          order_by: [asc: winner.position]
        )
      )

    snapshot_by_user = Map.new(snapshots, &{&1.user_id, &1})
    entries_by_user = Map.new(list_entries_for_drawing(campaign.id), &{&1.user_id, &1})

    Enum.map(positions, fn winner ->
      source =
        Map.get(snapshot_by_user, winner.user_id) || Map.get(entries_by_user, winner.user_id)

      %{
        position: winner.position,
        user_id: winner.user_id,
        username: source && source.username,
        display_name: source && source.display_name
      }
    end)
  end

  defp snapshot_map(snapshot) do
    Map.take(snapshot, [
      :entry_id,
      :user_id,
      :username,
      :display_name,
      :entry_inserted_at,
      :weight,
      :draw_order
    ])
  end

  defp entry_map(entry) do
    Map.take(entry, [:id, :user_id, :username, :display_name, :weight, :inserted_at])
  end

  defp entry_exists?(campaign_id, user_id) do
    Repo.one(
      from(entry in LotteryEntry,
        select: entry.id,
        where: entry.campaign_id == ^campaign_id and entry.user_id == ^user_id,
        limit: 1
      )
    ) != nil
  end

  defp referrals_enabled?(%LotteryCampaign{enable_referrals: false}), do: false
  defp referrals_enabled?(_campaign), do: true

  defp invitee_name(user), do: display_name(user)

  defp notify_referrer(%{campaign: campaign, referral: referral, weight: weight}) do
    invitee = referral.invitee_name || "好友"

    text =
      MessageTemplates.render(campaign.chat_id, :lottery_referral_completed, %{
        title: campaign.title,
        invitee: invitee,
        weight: weight
      })

    case Telegex.send_message(referral.inviter_id, text, disable_web_page_preview: true) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Lottery referral notification failed: #{inspect(reason)}",
          user_id: referral.inviter_id,
          campaign_id: campaign.id
        )

        :error
    end
  end

  defp campaign_group_title(campaign) do
    case Chat.get(campaign.chat_id) do
      {:ok, %{title: title}} when is_binary(title) and title != "" -> title
      _ -> "目标群组"
    end
  end

  defp campaign_group_link(campaign) do
    case Chat.get(campaign.chat_id) do
      {:ok, %{invite_link: link}} when is_binary(link) and link != "" ->
        link

      {:ok, %{username: username}} when is_binary(username) and username != "" ->
        "https://t.me/#{String.trim_leading(username, "@")}"

      {:ok, chat} ->
        case Telegex.export_chat_invite_link(campaign.chat_id) do
          {:ok, link} when is_binary(link) and link != "" ->
            _ = Instances.update_chat(chat, %{invite_link: link})
            link

          {:error, reason} ->
            Logger.warning("Lottery group invite link export failed: #{inspect(reason)}",
              chat_id: campaign.chat_id
            )

            nil

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp display_name(user) do
    name = String.trim("#{Map.get(user, :first_name, "")} #{Map.get(user, :last_name, "")}")
    if name == "", do: "用户 #{Map.get(user, :id)}", else: name
  end

  defp normalize_keyword(nil), do: nil

  defp normalize_keyword(value) do
    value = normalize_keyword_text(to_string(value))
    if value == "", do: nil, else: value
  end

  defp normalize_keyword_text(value), do: value |> String.trim() |> String.normalize(:nfc)

  defp truthy?(value), do: value in [true, "true", 1, "1"]

  defp maybe_pin(_chat_id, _message_id, false), do: :ok

  defp maybe_pin(chat_id, message_id, true) do
    case Telegex.pin_chat_message(chat_id, message_id, disable_notification: false) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("Lottery message pin failed: #{inspect(reason)}", chat_id: chat_id)

      _ ->
        Logger.warning("Lottery message pin returned an unexpected result", chat_id: chat_id)
    end
  end

  defp blank?(nil), do: true
  defp blank?(value), do: String.trim(value) == ""

  defp escape(value),
    do:
      value
      |> to_string()
      |> String.replace("&", "&amp;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")

  defp normalize_chat_id!(chat_id) when is_integer(chat_id), do: chat_id
  defp normalize_chat_id!(chat_id) when is_binary(chat_id), do: String.to_integer(chat_id)
end
