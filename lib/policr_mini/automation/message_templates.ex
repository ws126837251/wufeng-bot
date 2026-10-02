defmodule PolicrMini.Automation.MessageTemplates do
  @moduledoc false

  @placeholder ~r/(\{[a-z_]+\})/
  @exact_placeholder ~r/^\{([a-z_]+)\}$/

  @defaults %{
    "verification_entry_single" => "欢迎 {mention} 加入本群，您当前需要完成验证才能解除限制，验证有效时间不超过 {seconds} 秒。",
    "verification_entry_multiple" =>
      "欢迎 {mention} 和另外 {remaining_count} 位新成员加入本群，请主动完成验证以解除限制，验证有效时间不超过 {seconds} 秒。",
    "verification_expiry_warning" => "过期会被踢出或封禁，请尽快。",
    "verification_success" => "验证成功🔓",
    "lottery_join_success" => "✅ 报名成功！当前已有 {count} 人参加。",
    "lottery_join_duplicate" => "你已经参加过这次抽奖了～",
    "lottery_keyword_mismatch" => "❌ 参与关键词不正确，请回复：{keyword}",
    "lottery_keyword_ambiguous" => "⚠️ 多场抽奖使用了相同关键词，请回复对应的抽奖消息参加。",
    "lottery_panel_prompt" => "🎁 点击下方按钮，直接打开当前群的抽奖中心。",
    "lottery_private_panel_prompt" => "🎁 点击下方按钮进入当前群的抽奖中心。",
    "lottery_admin_only" => "只有本群群主可以打开抽奖设置。其他管理员可在后台提交操作申请，由群主私聊审批。",
    "lottery_draw_none" => "当前群没有进行中的抽奖。",
    "lottery_draw_closed" => "当前抽奖已经结束或已开奖。",
    "lottery_draw_failed" => "主动开奖失败，请稍后重试。",
    "lottery_draw_admin_only" => "只有群管理员可以主动开奖。",
    "management_approval_submitted" => "🔐 操作已提交群主审批，请群主在 WuFengBot 私聊中确认。",
    "management_approval_owner_unavailable" => "⚠️ 无法向群主发送审批通知，请群主先私聊 WuFengBot 并发送 /start。",
    "management_approval_private" =>
      "🔐 群管理操作待确认\n\n群组：{chat_title}\n申请人：{requester}（ID {requester_id}）\n操作：{summary}\n状态：{status}\n\n只有群主点击同意后，WuFengBot 才会执行该操作。",
    "active_lottery_none" => "当前群没有正在进行的抽奖。",
    "active_lottery_header" => "🎁 正在抽奖（{count} 场）",
    "active_lottery_item" =>
      "{title}\n奖品：{prize}\n参与人数：{participants}\n开奖时间：{end_at}\n参与方式：{entry_method}",
    "lottery_button_invalid" => "无效的抽奖按钮",
    "lottery_button_joined" => "报名成功，祝你好运！",
    "lottery_button_duplicate" => "你已经报名过了～",
    "lottery_button_closed" => "本次抽奖已经结束",
    "lottery_button_not_found" => "抽奖不存在",
    "lottery_button_failed" => "报名失败，请稍后再试",
    "lottery_button_invite_sent" => "邀请链接已发送到你的私聊。",
    "lottery_button_invite_invalid" => "邀请入口已失效，请稍后重试。",
    "lottery_referral_disabled" => "本次抽奖未开启邀请好友功能。",
    "lottery_invite_prompt" =>
      "🎁 邀请好友一起抽奖\n\n抽奖：{title}\n好友打开下方链接进入群组并完成验证，你的中奖权重将提高。\n\n{link}",
    "lottery_referral_join_prompt" =>
      "🎁 你已接受抽奖邀请\n\n请点击下方按钮进入「{group}」并完成入群验证。验证成功后，邀请人的中奖权重将提高。",
    "lottery_referral_pending" => "邀请关系已记录，请点击下方按钮进入群组并完成验证。",
    "lottery_referral_already_completed" => "这条邀请已经完成验证，无需重复操作。",
    "lottery_referral_self" => "不能使用自己的邀请链接。",
    "lottery_referral_inviter_not_joined" => "该邀请链接暂不可用，邀请人还没有参加这场抽奖。",
    "lottery_referral_group_link_unavailable" => "暂时无法生成群组邀请链接，请联系群管理员检查机器人权限。",
    "lottery_referral_invalid" => "邀请链接无效或抽奖已经结束。",
    "lottery_referral_completed" =>
      "🎉 你邀请的 {invitee} 已进群并完成验证！\n\n你在抽奖「{title}」中的当前中奖权重为 {weight}。",
    "lottery_campaign" =>
      "{mention}🎁 {title}\n\n奖品：{prize}\n参与人数：{count}\n开奖时间：{end_at}{keyword}{description}",
    "lottery_result" => "🎉 {title} 已开奖\n\n奖品：{prize}\n\n中奖者：\n{winners}",
    "lottery_result_empty" => "无人参与，本次抽奖未产生中奖者。",
    "scheduled_message_test" => "🧪 定时消息测试｜{title}\n\n{text}",
    "manage_prompt" => "管理功能仅在 WuFengBot 私聊页面显示，请点击下方按钮打开。",
    "manage_admin_only" => "只有群管理员可以打开管理快捷页。",
    "status_body" =>
      "❤️ WuFengBot 运行状态\n\n服务状态：{status}\n群组接管：{takeover}\n管理员：{administrator}\n发送消息：{send_messages}\n删除消息：{delete_messages}\n限制成员：{restrict_members}\n置顶消息：{pin_messages}",
    "status_failed" => "⚠️ 暂时无法读取机器人状态，请稍后重试。",
    "status_admin_only" => "只有群管理员可以检查机器人权限状态。",
    "member_blacklist_command_usage" =>
      "用法：/ban @用户名 [原因]\n选择成员时也支持 /ban@成员 [原因]；还可以回复成员消息后发送 /ban [原因]，或使用 /ban 数字ID [原因]。",
    "member_blacklist_command_admin_only" => "只有具备成员管理权限的群管理员可以使用 /ban。",
    "member_blacklist_command_not_found" => "未在当前群找到成员 {target}，请检查用户名，或回复该成员的消息后再试。",
    "member_blacklist_command_protected" => "无法处理 {target}：群主、管理员和 WuFengBot 受保护。",
    "member_blacklist_command_success" => "✅ 已将 {target} 移出群组并加入永久黑名单。",
    "member_blacklist_command_failed" => "永久拉黑失败：{reason}",
    "join_request_entry_single" =>
      "用户 {mention} 正在验证！\n\n加群请求会根据验证结果自动处理，并按照方案决定是否进一步封禁。\n验证有效时间不超过 {seconds} 秒。",
    "join_request_entry_multiple" =>
      "最近申请加入的 {mention} 和另外 {remaining_count} 个用户正在验证！\n\n加群请求会根据验证结果自动处理，并按照方案决定是否进一步封禁。\n验证有效时间不超过 {seconds} 秒。",
    "verification_private_prompt" =>
      "来自『{chat_title}』的验证，请确认问题并选择您认为正确的答案。\n\n{question}\n\n您还剩 {seconds} 秒，通过可解除限制。",
    "verification_failed_banned" => "抱歉，您未通过『{chat_title}』的加群验证。已被封禁。",
    "verification_failed_removed" =>
      "抱歉，您未通过『{chat_title}』的加群验证。已被移出该群。\n\n提示：可稍后重新尝试，但无法立刻再次加入。",
    "join_request_failed_banned" => "抱歉，您未通过『{chat_title}』的加群验证。已拒绝加入请求并被禁止再次申请加入。",
    "join_request_failed_rejected" =>
      "抱歉，您未通过『{chat_title}』的加群验证。已拒绝加入请求。\n\n提示：可稍后重新尝试，但无法立刻再次申请加入。"
  }

  @catalog [
    {"verification", "验证与欢迎",
     [
       {"verification_entry_single", "入群验证（单人）", "群内出现一位待验证成员时发送。", "{mention} {seconds}", 3},
       {"verification_entry_multiple", "入群验证（多人）", "群内同时有多位待验证成员时发送。",
        "{mention} {remaining_count} {seconds}", 3},
       {"verification_expiry_warning", "验证过期提醒", "显示在群内验证入口底部。", "", 2},
       {"verification_success", "验证成功", "验证通过后在群内和用户私聊中发送。", "", 2},
       {"join_request_entry_single", "加群申请验证（单人）", "一位用户通过加群申请进入验证时发送。", "{mention} {seconds}",
        4},
       {"join_request_entry_multiple", "加群申请验证（多人）", "多位加群申请用户正在验证时发送。",
        "{mention} {remaining_count} {seconds}", 4},
       {"verification_private_prompt", "私聊验证题目", "机器人向待验证用户发送题目时使用。",
        "{chat_title} {question} {seconds}", 5},
       {"verification_failed_banned", "验证失败并封禁", "普通入群验证失败且执行封禁时发送。", "{chat_title}", 3},
       {"verification_failed_removed", "验证失败并移出", "普通入群验证失败且临时移出时发送。", "{chat_title}", 4},
       {"join_request_failed_banned", "申请验证失败并封禁", "加群申请验证失败且封禁时发送。", "{chat_title}", 3},
       {"join_request_failed_rejected", "申请验证失败并拒绝", "加群申请验证失败且拒绝时发送。", "{chat_title}", 4}
     ]},
    {"lottery", "抽奖活动",
     [
       {"lottery_campaign", "抽奖发布内容", "创建抽奖后发送到群内的主消息。",
        "{mention} {title} {prize} {count} {end_at} {keyword} {description}", 7},
       {"lottery_result", "开奖结果", "开奖完成后发送。", "{title} {prize} {winners}", 5},
       {"lottery_result_empty", "无人参与结果", "抽奖无人参与时填入中奖者位置。", "", 2},
       {"scheduled_message_test", "定时消息试发内容", "在控制台点击“试发”时发送到当前群组。", "{title} {text}", 4},
       {"lottery_join_success", "关键词报名成功", "使用关键词成功参加时回复。", "{count}", 2},
       {"lottery_join_duplicate", "关键词重复报名", "重复发送参与关键词时回复。", "", 2},
       {"lottery_keyword_mismatch", "参与关键词错误", "回复了错误关键词时发送。", "{keyword}", 2},
       {"lottery_keyword_ambiguous", "参与关键词冲突", "多场活动关键词相同时发送。", "", 2},
       {"lottery_button_invalid", "按钮无效", "点击无法识别的抽奖按钮时弹出。", "", 2},
       {"lottery_button_joined", "按钮报名成功", "点击按钮成功参加时弹出。", "", 2},
       {"lottery_button_duplicate", "按钮重复报名", "重复点击参加按钮时弹出。", "", 2},
       {"lottery_button_closed", "按钮报名已结束", "活动结束后点击参加按钮时弹出。", "", 2},
       {"lottery_button_not_found", "抽奖不存在", "抽奖记录不存在时弹出。", "", 2},
       {"lottery_button_failed", "按钮报名失败", "报名发生异常时弹出。", "", 2},
       {"lottery_button_invite_sent", "邀请链接已发送", "点击邀请好友按钮后弹出。", "", 2},
       {"lottery_button_invite_invalid", "邀请入口失效", "邀请活动不存在或已结束时弹出。", "", 2},
       {"lottery_referral_disabled", "邀请功能未开启", "本场抽奖关闭邀请功能时发送。", "", 2},
       {"lottery_invite_prompt", "抽奖邀请链接", "报名成功后发送给参与者的邀请说明。", "{title} {link} {group}", 6},
       {"lottery_referral_join_prompt", "接受抽奖邀请", "好友打开邀请深链接后发送。", "{group}", 5},
       {"lottery_referral_pending", "邀请关系待验证", "好友重复打开邀请链接但还未完成验证时发送。", "", 3},
       {"lottery_referral_already_completed", "邀请已完成", "好友重复打开已完成的邀请链接时发送。", "", 2},
       {"lottery_referral_self", "不能邀请自己", "邀请人打开自己的邀请链接时发送。", "", 2},
       {"lottery_referral_inviter_not_joined", "邀请人未报名", "邀请人尚未参加该活动时发送。", "", 3},
       {"lottery_referral_group_link_unavailable", "群组邀请链接不可用", "机器人无法生成目标群组邀请链接时发送。", "", 4},
       {"lottery_referral_invalid", "邀请链接无效", "邀请参数无效或活动已结束时发送。", "", 3},
       {"lottery_referral_completed", "邀请完成通知", "好友入群并通过验证后通知邀请人。", "{title} {invitee} {weight}", 4},
       {"lottery_panel_prompt", "/lottery 面板提示", "群管理员执行 /lottery 时发送。", "", 2},
       {"lottery_private_panel_prompt", "私聊抽奖面板提示", "从私聊进入指定群抽奖中心时发送。", "", 2},
       {"lottery_admin_only", "/lottery 无权限", "非群主执行 /lottery 时发送。", "", 3},
       {"lottery_draw_none", "没有正在抽奖", "执行 /draw 但没有活动时发送。", "", 2},
       {"lottery_draw_closed", "抽奖已经结束", "执行 /draw 但活动已关闭时发送。", "", 2},
       {"lottery_draw_failed", "主动开奖失败", "执行 /draw 发生异常时发送。", "", 2},
       {"lottery_draw_admin_only", "开奖无权限", "非管理员执行 /draw 时发送。", "", 2},
       {"management_approval_submitted", "管理操作已提交审批", "群内管理操作进入群主私聊审批时发送。", "", 2},
       {"management_approval_owner_unavailable", "群主私聊不可用", "机器人无法向群主发送审批通知时发送。", "", 3},
       {"management_approval_private", "群主私聊审批通知", "有管理操作等待群主确认时发送，并在处理后更新状态。",
        "{chat_title} {requester} {requester_id} {summary} {status}", 7},
       {"active_lottery_none", "/active 无活动", "没有进行中的抽奖时发送。", "", 2},
       {"active_lottery_header", "/active 标题", "正在抽奖列表的标题。", "{count}", 2},
       {"active_lottery_item", "/active 活动内容", "正在抽奖列表中的单个活动。",
        "{title} {prize} {participants} {end_at} {entry_method}", 6}
     ]},
    {"commands", "命令与状态",
     [
       {"manage_prompt", "/manage 管理入口", "管理员执行 /manage 时发送。", "", 2},
       {"manage_admin_only", "/manage 无权限", "非管理员执行 /manage 时发送。", "", 2},
       {"status_body", "/status 状态内容", "机器人权限巡检成功后发送。",
        "{status} {takeover} {administrator} {send_messages} {delete_messages} {restrict_members} {pin_messages}",
        9},
       {"status_failed", "/status 检查失败", "状态巡检失败时发送。", "", 2},
       {"status_admin_only", "/status 无权限", "非管理员执行 /status 时发送。", "", 2},
       {"member_blacklist_command_usage", "/ban 使用说明", "未指定有效目标时发送。", "", 3},
       {"member_blacklist_command_admin_only", "/ban 无权限", "无成员管理权限的用户执行 /ban 时发送。", "", 2},
       {"member_blacklist_command_not_found", "/ban 未找到成员", "目标不在当前群成员名单时发送。", "{target}", 3},
       {"member_blacklist_command_protected", "/ban 目标受保护", "目标是群主、管理员或 WuFengBot 时发送。",
        "{target}", 3},
       {"member_blacklist_command_success", "/ban 执行成功", "群主直接执行永久拉黑成功时发送。", "{target}", 2},
       {"member_blacklist_command_failed", "/ban 执行失败", "命令无法提交或执行时发送。", "{reason}", 2}
     ]}
  ]

  def defaults, do: @defaults

  @doc false
  def normalize_keys(templates) when is_map(templates) do
    aliases = Map.new(Map.keys(@defaults), &{camel_key(&1), &1})

    Enum.reduce(templates, %{}, fn
      {key, value}, normalized when is_binary(key) ->
        canonical_key = Map.get(aliases, key, key)

        if key == canonical_key or not Map.has_key?(templates, canonical_key) do
          Map.put(normalized, canonical_key, value)
        else
          normalized
        end

      {key, value}, normalized ->
        Map.put(normalized, key, value)
    end)
  end

  def normalize_keys(templates), do: templates

  def catalog do
    Enum.map(@catalog, fn {id, label, fields} ->
      %{
        id: id,
        label: label,
        fields:
          Enum.map(fields, fn {key, field_label, description, variables, rows} ->
            %{
              key: key,
              label: field_label,
              description: description,
              variables: variables,
              rows: rows,
              default_text: Map.fetch!(@defaults, key)
            }
          end)
      }
    end)
  end

  def merged(custom) when is_map(custom) do
    custom =
      Enum.into(custom, %{}, fn
        {key, value} when is_binary(value) -> {key, String.trim(value)}
        {key, _value} -> {key, ""}
      end)
      |> Enum.reject(fn {_key, value} -> value == "" end)
      |> Map.new()

    Map.merge(@defaults, custom)
  end

  def merged(_custom), do: @defaults

  def render(chat_id, key, bindings \\ %{}, opts \\ []) do
    template =
      chat_id
      |> PolicrMini.Automation.get_settings!()
      |> Map.get(:message_templates)
      |> merged()
      |> Map.fetch!(to_string(key))

    render_template(template, bindings, Keyword.get(opts, :parse_mode))
  end

  @doc false
  def render_template(template, bindings, parse_mode \\ nil)
      when is_binary(template) and is_map(bindings) do
    Regex.split(@placeholder, template, include_captures: true, trim: false)
    |> Enum.map_join(fn part -> render_part(part, bindings, parse_mode) end)
  end

  defp render_part(part, bindings, parse_mode) do
    case Regex.run(@exact_placeholder, part) do
      [_, key] ->
        bindings
        |> binding_value(key)
        |> to_string()

      _ ->
        escape_static(part, parse_mode)
    end
  end

  defp binding_value(bindings, key) do
    Map.get(bindings, key, Map.get(bindings, String.to_existing_atom(key), ""))
  rescue
    ArgumentError -> Map.get(bindings, key, "")
  end

  defp escape_static(text, "MarkdownV2"), do: Telegex.Tools.safe_markdown(text)
  defp escape_static(text, "HTML"), do: Telegex.Tools.safe_html(text)
  defp escape_static(text, _parse_mode), do: text

  defp camel_key(key) do
    [first | rest] = String.split(key, "_")
    first <> Enum.map_join(rest, &String.capitalize/1)
  end
end
