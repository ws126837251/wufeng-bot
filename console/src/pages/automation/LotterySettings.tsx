import { createSignal, For, Show } from "solid-js";
import { getLotteryAudit, getLotteryEntries } from "../../api";
import { ActionButton } from "../../components";
import { toaster } from "../../utils";
import { isApprovalPending } from "../../api";
import { inputClass, localDateTime, NumberField, SettingCard, Toggle, toSeconds } from "./controls";

type Props = { chatId: number; items: ServerData.Lottery[]; onCreate: (input: InputData.Lottery) => Promise<ApiResponse<ServerData.Lottery>>; onDraw: (id: number) => Promise<ApiResponse<ServerData.Lottery>>; onCancel: (id: number) => Promise<ApiResponse<ServerData.Lottery>>; };

export const LotterySettings = (props: Props) => {
  const [title, setTitle] = createSignal("");
  const [prize, setPrize] = createSignal("");
  const [description, setDescription] = createSignal("");
  const [keyword, setKeyword] = createSignal("");
  const [winnerCount, setWinnerCount] = createSignal(1);
  const [at, setAt] = createSignal(localDateTime(new Date(Date.now() + 3_600_000)));
  const [enableReferrals, setEnableReferrals] = createSignal(true);
  const [mentionAll, setMentionAll] = createSignal(false);
  const [pinMessage, setPinMessage] = createSignal(false);
  const [autoDeleteEntryMessages, setAutoDeleteEntryMessages] = createSignal(false);
  const [entryMessageDeleteAfterSeconds, setEntryMessageDeleteAfterSeconds] = createSignal(8);
  const [expandedId, setExpandedId] = createSignal<number | null>(null);
  const [participants, setParticipants] = createSignal<Record<number, ServerData.LotteryEntry[]>>({});
  const [audit, setAudit] = createSignal<ServerData.LotteryAudit | null>(null);
  const [loadingId, setLoadingId] = createSignal<number | null>(null);
  const [actionId, setActionId] = createSignal<number | null>(null);

  const create = async () => {
    if (!title().trim() || !prize().trim()) return;
    const response = await props.onCreate({ title: title().trim(), prize: prize().trim(), description: description().trim(), winner_count: winnerCount(), entry_keyword: keyword().trim(), end_at: new Date(at()).toISOString(), enable_referrals: enableReferrals(), mention_all: mentionAll(), pin_message: pinMessage(), auto_delete_entry_messages: autoDeleteEntryMessages(), entry_message_delete_after_seconds: entryMessageDeleteAfterSeconds() });
    if (isApprovalPending(response)) { resetForm(); return; }
    if (response.success) { toaster.success({ title: "抽奖已发布", description: keyword().trim() ? `群成员回复“${keyword().trim()}”即可参加` : "群成员点击报名按钮即可参加" }); resetForm(); } else toaster.error({ title: "创建抽奖失败", description: response.message });
  };
  const resetForm = () => { setTitle(""); setPrize(""); setDescription(""); setKeyword(""); setEnableReferrals(true); setMentionAll(false); setPinMessage(false); setAutoDeleteEntryMessages(false); setEntryMessageDeleteAfterSeconds(8); };
  const toggleParticipants = async (lotteryId: number) => {
    if (expandedId() === lotteryId) { setExpandedId(null); return; }
    setExpandedId(lotteryId);
    if (participants()[lotteryId]) return;
    setLoadingId(lotteryId);
    try {
      const response = await getLotteryEntries(props.chatId, lotteryId);
      if (response.success) setParticipants((current) => ({ ...current, [lotteryId]: response.payload })); else toaster.error({ title: "读取参与者失败", description: response.message, duration: 5_000 });
    } finally {
      setLoadingId(null);
    }
  };
  const openAudit = async (lotteryId: number) => {
    setLoadingId(lotteryId);
    try {
      const response = await getLotteryAudit(props.chatId, lotteryId);
      if (response.success) setAudit(response.payload); else toaster.error({ title: "读取开奖凭证失败", description: response.message, duration: 5_000 });
    } finally {
      setLoadingId(null);
    }
  };
  const runLotteryAction = async (id: number, action: "draw" | "cancel") => {
    setActionId(id);
    try {
      const response = action === "draw" ? await props.onDraw(id) : await props.onCancel(id);
      if (isApprovalPending(response)) return;
      if (response.success) {
        toaster.success({ title: action === "draw" ? "开奖已完成" : "活动已取消", description: action === "draw" ? "开奖结果已发送到群内。" : "该抽奖活动不会再接受报名。", duration: 3_500 });
      } else {
        toaster.error({ title: action === "draw" ? "开奖未执行" : "取消未执行", description: response.message, duration: 5_000 });
      }
    } finally {
      setActionId(null);
    }
  };

  return <div class="grid gap-5 xl:grid-cols-[minmax(0,.9fr)_minmax(0,1.1fr)]">
    <SettingCard icon="solar:gift-bold-duotone" title="创建抽奖" description="参与关键词由你设置；留空时改用按钮报名。邀请好友功能可按场次开关。"><input class={inputClass} value={title()} onInput={(event) => setTitle(event.currentTarget.value)} placeholder="活动标题，例如：周末抽奖" /><input class={inputClass} value={prize()} onInput={(event) => setPrize(event.currentTarget.value)} placeholder="奖品，例如：50 元红包" /><label class="panel-muted">自定义参与关键词<input class={inputClass + " mt-1"} value={keyword()} maxLength={80} onInput={(event) => setKeyword(event.currentTarget.value)} placeholder="例如：参与、我要抽奖、指定链接" /><span class="mt-1 block text-xs leading-5 text-emerald-950/50">填写后，群成员必须回复抽奖消息并发送完全相同的内容；前后空格会自动忽略。留空则显示“立即参加”按钮。</span></label><textarea class={inputClass} rows="4" value={description()} onInput={(event) => setDescription(event.currentTarget.value)} placeholder="活动说明（可选）" /><div class="grid gap-3 sm:grid-cols-2"><NumberField label="中奖人数" value={winnerCount()} onInput={(value) => setWinnerCount(toSeconds(value, 1, 100))} min={1} max={100} /><label class="panel-muted">开奖时间<input class={inputClass + " mt-1"} type="datetime-local" value={at()} onInput={(event) => setAt(event.currentTarget.value)} /></label></div><div class="space-y-2 rounded-xl border border-tea-500/15 bg-tea-50/70 p-3"><p class="text-sm font-bold text-tea-700">发布后动作</p><Toggle label="允许邀请好友提高中奖权重" checked={enableReferrals()} onChange={setEnableReferrals} /><p class="text-xs leading-5 text-emerald-950/50">关闭后本场抽奖不显示邀请按钮，邀请链接也不会生效。</p><Toggle label="显示 @全体成员 提醒" checked={mentionAll()} onChange={setMentionAll} /><p class="text-xs leading-5 text-emerald-950/50">Telegram 不支持真实全员提及；此选项会在抽奖消息顶部显示醒目的提醒。</p><Toggle label="发布后自动置顶" checked={pinMessage()} onChange={setPinMessage} /><Show when={keyword().trim()} fallback={<p class="text-xs leading-5 text-emerald-950/50">填写参与关键词后，可设置自动删除成员的报名回复。</p>}><Toggle label="成功报名后自动删除成员回复" checked={autoDeleteEntryMessages()} onChange={setAutoDeleteEntryMessages} /><Show when={autoDeleteEntryMessages()}><NumberField label="报名消息删除延迟（秒）" value={entryMessageDeleteAfterSeconds()} onInput={(value) => setEntryMessageDeleteAfterSeconds(toSeconds(value, 1, 172_740))} min={1} max={172_740} /></Show><p class="text-xs leading-5 text-emerald-950/50">仅删除成功命中的关键词报名消息（包括重复报名）；错误关键词不会删除。</p></Show></div><ActionButton variant="info" size="lg" fullWidth onClick={create}>发布抽奖</ActionButton></SettingCard>
    <SettingCard icon="solar:chart-2-bold-duotone" title="活动列表" description="查看参与名单、邀请权重、主动开奖和可验证开奖凭证。"><Show when={props.items.length > 0} fallback={<p class="panel-muted rounded-xl bg-tea-50 p-4 text-center">当前群组暂无抽奖活动。</p>}><div class="space-y-3"><For each={props.items}>{(item) => { const entries = () => participants()[item.id] || []; return <div class="rounded-2xl border border-emerald-950/8 p-4"><div class="flex items-start justify-between gap-3"><div><strong class="text-base">{item.title}</strong><p class="mt-1 text-sm text-emerald-950/60">奖品：{item.prize} · {item.participantCount} 人报名 · {item.winnerCount} 个名额</p></div><Status status={item.status} /></div><p class="mt-2 break-all text-xs text-emerald-950/45">参与方式：{item.entryKeyword ? `回复“${item.entryKeyword}”` : "点击报名按钮"} · 邀请：{item.enableReferrals !== false ? "开启" : "关闭"} · 开奖：{new Date(item.endAt).toLocaleString()}</p><Show when={item.entryKeyword}><p class="mt-1 text-xs text-emerald-950/45">报名消息：{item.autoDeleteEntryMessages ? `${item.entryMessageDeleteAfterSeconds} 秒后自动删除` : "保留"}</p></Show><div class="mt-3 flex flex-wrap gap-2"><ActionButton variant="info" size="sm" loading={loadingId() === item.id} onClick={() => toggleParticipants(item.id)}>{expandedId() === item.id ? "收起参与者" : `查看参与者（${item.participantCount}）`}</ActionButton><Show when={item.status === "drawn"}><ActionButton variant="info" outline size="sm" loading={loadingId() === item.id} onClick={() => openAudit(item.id)}>开奖凭证</ActionButton></Show><Show when={item.status === "active"}><ActionButton variant="info" size="sm" loading={actionId() === item.id} onClick={() => runLotteryAction(item.id, "draw")}>立即开奖</ActionButton><ActionButton variant="danger" size="sm" loading={actionId() === item.id} onClick={() => runLotteryAction(item.id, "cancel")}>取消活动</ActionButton></Show></div><Show when={expandedId() === item.id}><div class="mt-3 space-y-2 rounded-xl bg-tea-50 p-3"><Show when={entries().length > 0} fallback={<p class="panel-muted text-center">暂无参与者</p>}><For each={entries()}>{(participant) => <div class="flex items-center justify-between gap-3 border-b border-emerald-950/8 py-2 last:border-0"><div class="min-w-0"><p class="truncate text-sm font-semibold text-ink">{participant.displayName}</p><p class="truncate text-xs text-emerald-950/50">{participant.username ? `@${participant.username}` : "无用户名"} · ID {participant.userId} · 权重 {participant.weight || 1}</p></div><time class="shrink-0 text-xs text-emerald-950/45">{new Date(participant.insertedAt).toLocaleString()}</time></div>}</For></Show></div></Show></div>; }}</For></div></Show></SettingCard>
    <Show when={audit()}>{(value) => <section class="panel-card col-span-full p-5"><div class="flex items-start justify-between gap-3"><div><h2 class="panel-section-title">开奖凭证 · {value().campaign.title}</h2><p class="panel-muted mt-1">开奖时已冻结参与名单；排序可通过下方种子与摘要复核。</p></div><ActionButton variant="info" outline size="sm" onClick={() => setAudit(null)}>关闭</ActionButton></div><Show when={value().proof.available} fallback={<p class="mt-4 rounded-xl bg-amber-50 p-3 text-sm text-amber-800">这是旧活动，创建时尚未启用可验证开奖，因此没有快照凭证。</p>}><div class="mt-4 grid gap-3 lg:grid-cols-2"><CodeBlock label="随机种子" value={value().proof.seed || ""} /><CodeBlock label="参与名单 SHA-256 摘要" value={value().proof.entriesDigest || ""} /></div><p class="mt-3 text-xs text-emerald-950/50">算法：{value().proof.algorithm} · 冻结名单 {value().proof.snapshotCount} 人。</p></Show><div class="mt-5 grid gap-4 lg:grid-cols-2"><div><h3 class="font-bold text-ink">中奖名单</h3><ol class="mt-2 space-y-2"><For each={value().winners}>{(winner) => <li class="rounded-xl bg-tea-50 px-3 py-2 text-sm">#{winner.position} · {winner.displayName || `用户 ${winner.userId}`} {winner.username && <span class="text-emerald-950/45">@{winner.username}</span>}</li>}</For></ol></div><div><h3 class="font-bold text-ink">冻结参与顺序</h3><div class="mt-2 max-h-64 space-y-2 overflow-y-auto"><For each={value().snapshot}>{(participant) => <div class="rounded-xl border border-emerald-950/8 px-3 py-2 text-sm">#{participant.drawOrder} · {participant.displayName} <span class="text-emerald-950/45">权重 {participant.weight || 1}</span> · ID {participant.userId}</div>}</For></div></div></div></section>}</Show>
  </div>;
};

const Status = (props: { status: ServerData.Lottery["status"] }) => <span class={props.status === "active" ? "rounded-full bg-amber-100 px-2 py-1 text-xs font-semibold text-amber-700" : "rounded-full bg-emerald-50 px-2 py-1 text-xs font-semibold text-emerald-950/55"}>{props.status === "active" ? "进行中" : props.status === "drawn" ? "已开奖" : "已取消"}</span>;
const CodeBlock = (props: { label: string; value: string }) => <label class="panel-muted">{props.label}<textarea class={inputClass + " mt-1 font-mono text-xs"} rows="2" readOnly value={props.value} /></label>;
