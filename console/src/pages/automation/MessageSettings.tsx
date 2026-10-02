import { Icon } from "@iconify-icon/solid";
import { createSignal, For, Show } from "solid-js";
import { ActionButton } from "../../components";
import { toaster } from "../../utils";
import { isApprovalPending } from "../../api";
import { inputClass, NumberField, SettingCard, Toggle, toSeconds } from "./controls";
import { MessageTemplateEditor } from "./MessageTemplateEditor";
import { KeywordReplySettings } from "./KeywordReplySettings";

type Props = {
  readOnly: boolean;
  activeCategory: MessageCategory; onCategoryChange: (value: MessageCategory) => void;
  autoDelete: boolean; botDeleteAfter: number; setAutoDelete: (value: boolean) => void; setBotDeleteAfter: (value: number) => void;
  welcomeEnabled: boolean; welcomeText: string; welcomeDeleteAfter: number; setWelcomeEnabled: (value: boolean) => void; setWelcomeText: (value: string) => void; setWelcomeDeleteAfter: (value: number) => void;
  forbiddenEnabled: boolean; escalationEnabled: boolean; warningText: string; warningDeleteAfter: number; setForbiddenEnabled: (value: boolean) => void; setEscalationEnabled: (value: boolean) => void; setWarningText: (value: string) => void; setWarningDeleteAfter: (value: number) => void;
  messageTemplates: Record<string, string>; messageTemplateCatalog: ServerData.MessageTemplateGroup[]; setMessageTemplate: (key: string, value: string) => void;
  words: ServerData.ForbiddenWord[]; whitelist: ServerData.ForbiddenWhitelistRule[]; events: ServerData.ModerationEvent[]; schedules: ServerData.Schedule[];
  keywordReplies: ServerData.KeywordReply[];
  onAddWord: (input: InputData.ForbiddenWord) => Promise<ApiResponse<ServerData.ForbiddenWord>>; onRemoveWord: (id: number) => Promise<ApiResponse<ServerData.ForbiddenWord>>;
  onAddWhitelist: (input: InputData.ForbiddenWhitelistRule) => Promise<ApiResponse<ServerData.ForbiddenWhitelistRule>>; onRemoveWhitelist: (id: number) => Promise<ApiResponse<ServerData.ForbiddenWhitelistRule>>; onRefreshEvents: () => Promise<unknown>;
  onAddSchedule: (input: InputData.Schedule) => Promise<ApiResponse<ServerData.Schedule>>; onUpdateSchedule: (id: number, input: Partial<InputData.Schedule>) => Promise<ApiResponse<ServerData.Schedule>>; onTestSchedule: (id: number) => Promise<ApiResponse<ServerData.Schedule>>; onRemoveSchedule: (id: number) => Promise<ApiResponse<ServerData.Schedule>>;
  onAddKeywordReply: (input: InputData.KeywordReply) => Promise<ApiResponse<ServerData.KeywordReply>>; onUpdateKeywordReply: (id: number, input: InputData.KeywordReply) => Promise<ApiResponse<ServerData.KeywordReply>>; onRemoveKeywordReply: (id: number) => Promise<ApiResponse<ServerData.KeywordReply>>;
};

export type MessageCategory = "settings" | "templates" | "replies" | "moderation" | "schedules";

export const MessageSettings = (props: Props) => {
  const [word, setWord] = createSignal("");
  const [wordMode, setWordMode] = createSignal<InputData.ForbiddenWord["match_mode"]>("contains");
  const [wordAction, setWordAction] = createSignal<InputData.ForbiddenWord["action"]>("delete_warn");
  const [wordWarning, setWordWarning] = createSignal("");
  const [whiteWord, setWhiteWord] = createSignal("");
  const [scheduleTitle, setScheduleTitle] = createSignal("");
  const [scheduleText, setScheduleText] = createSignal("");
  const [scheduleAt, setScheduleAt] = createSignal(defaultScheduleTime());
  const [scheduleDeleteAfter, setScheduleDeleteAfter] = createSignal(0);
  const [preserveFirst, setPreserveFirst] = createSignal(false);
  const [editingScheduleId, setEditingScheduleId] = createSignal<number | null>(null);
  const [scheduleSaving, setScheduleSaving] = createSignal(false);
  const [scheduleActionId, setScheduleActionId] = createSignal<number | null>(null);

  const addWord = async () => {
    if (!word().trim()) return;
    const response = await props.onAddWord({ word: word().trim(), match_mode: wordMode(), case_sensitive: false, enabled: true, warning_text: wordWarning(), action: wordAction() });
    if (isApprovalPending(response)) { setWord(""); setWordWarning(""); return; }
    if (response.success) { setWord(""); setWordWarning(""); } else toaster.error({ title: "添加失败", description: response.message });
  };
  const addWhitelist = async () => {
    if (!whiteWord().trim()) return;
    const response = await props.onAddWhitelist({ word: whiteWord().trim(), match_mode: "contains", case_sensitive: false, enabled: true });
    if (isApprovalPending(response)) { setWhiteWord(""); return; }
    if (response.success) setWhiteWord(""); else toaster.error({ title: "添加白名单失败", description: response.message });
  };
  const resetSchedule = () => {
    setEditingScheduleId(null);
    setScheduleTitle("");
    setScheduleText("");
    setScheduleAt(defaultScheduleTime());
    setScheduleDeleteAfter(0);
    setPreserveFirst(false);
  };
  const saveSchedule = async () => {
    if (!scheduleTitle().trim() || !scheduleText().trim()) return;
    setScheduleSaving(true);
    try {
      const input = { title: scheduleTitle().trim(), text: scheduleText(), schedule_type: "one_time" as const, next_run_at: new Date(scheduleAt()).toISOString(), interval_seconds: null, preserve_first_message: preserveFirst(), delete_after_seconds: toSeconds(scheduleDeleteAfter()) };
      const response = editingScheduleId() === null ? await props.onAddSchedule(input) : await props.onUpdateSchedule(editingScheduleId()!, input);
      if (isApprovalPending(response) || response.success) {
        resetSchedule();
      } else {
        toaster.error({ title: editingScheduleId() === null ? "创建失败" : "保存失败", description: response.message });
      }
    } catch (error) {
      toaster.error({ title: "定时消息未保存", description: error instanceof Error ? error.message : "无法连接管理服务，请稍后重试。" });
    } finally {
      setScheduleSaving(false);
    }
  };
  const editSchedule = (item: ServerData.Schedule) => {
    setEditingScheduleId(item.id);
    setScheduleTitle(item.title);
    setScheduleText(item.text);
    setScheduleAt(toLocalDateTime(item.nextRunAt));
    setScheduleDeleteAfter(item.deleteAfterSeconds);
    setPreserveFirst(item.preserveFirstMessage);
  };
  const runScheduleAction = async (item: ServerData.Schedule, action: "toggle" | "test") => {
    if (action === "test" && !window.confirm(`确认向当前群发送「${item.title}」的测试消息？`)) return;
    setScheduleActionId(item.id);
    try {
      const response = action === "toggle"
        ? await props.onUpdateSchedule(item.id, { enabled: !item.enabled })
        : await props.onTestSchedule(item.id);
      if (isApprovalPending(response)) return;
      if (response.success) {
        toaster.success({ title: action === "toggle" ? (item.enabled ? "已暂停定时消息" : "已恢复定时消息") : "测试消息已发送", description: action === "toggle" ? item.title : "测试消息会按该任务的删除设置处理。" });
      } else {
        toaster.error({ title: "操作未执行", description: response.message });
      }
    } catch (error) {
      toaster.error({ title: "操作未执行", description: error instanceof Error ? error.message : "无法连接管理服务，请稍后重试。" });
    } finally {
      setScheduleActionId(null);
    }
  };
  const removeSchedule = (item: ServerData.Schedule) => {
    if (!window.confirm(`确认删除定时消息「${item.title}」？此操作不能恢复。`)) return;
    return props.onRemoveSchedule(item.id);
  };

  return <div class="space-y-5">
    <MessageCategorySwitcher active={props.activeCategory} templateCount={props.messageTemplateCatalog.reduce((count, group) => count + group.fields.length, 0)} onChange={props.onCategoryChange} />
    <fieldset disabled={props.readOnly} class={props.readOnly ? "contents pointer-events-none select-none opacity-70" : "contents"}>
    <div class="grid gap-5 xl:grid-cols-2">
      <Show when={props.activeCategory === "settings"}>
        <SettingCard icon="solar:trash-bin-minimalistic-bold-duotone" title="机器人消息自动删除" description="统一控制机器人发出的提示和回复消息。"><Toggle label="开启自动删除" checked={props.autoDelete} onChange={props.setAutoDelete} /><NumberField label="删除延时（秒）" value={props.botDeleteAfter} onInput={props.setBotDeleteAfter} hint="0 表示关闭，系统上限为 47 小时 59 分。" /></SettingCard>
        <SettingCard icon="solar:hand-stars-bold-duotone" title="入群欢迎" description="仅在验证通过后发送欢迎语，可按时间清理。"><Toggle label="开启欢迎信息" checked={props.welcomeEnabled} onChange={props.setWelcomeEnabled} /><textarea class={inputClass} rows="4" value={props.welcomeText} onInput={(event) => props.setWelcomeText(event.currentTarget.value)} placeholder="欢迎 {user} 加入本群！" /><div class="rounded-xl border border-tea-500/10 bg-tea-50/70 px-3 py-2.5 text-xs leading-5 text-emerald-950/60"><p class="font-bold text-tea-600">欢迎语编辑提示</p><p><code class="rounded bg-white px-1">&#123;user&#125;</code> 是进群人的姓名；<code class="rounded bg-white px-1">&#123;username&#125;</code> 是 Telegram 用户名；<code class="rounded bg-white px-1">&#123;id&#125;</code> 是用户 ID。</p></div><NumberField label="欢迎消息删除延时（秒）" value={props.welcomeDeleteAfter} onInput={props.setWelcomeDeleteAfter} /></SettingCard>
      </Show>
      <Show when={props.activeCategory === "templates"}>
        <div class="xl:col-span-2"><MessageTemplateEditor catalog={props.messageTemplateCatalog} values={props.messageTemplates} onChange={props.setMessageTemplate} /></div>
      </Show>
      <Show when={props.activeCategory === "replies"}>
        <KeywordReplySettings items={props.keywordReplies} onCreate={props.onAddKeywordReply} onUpdate={props.onUpdateKeywordReply} onDelete={props.onRemoveKeywordReply} />
      </Show>
      <Show when={props.activeCategory === "moderation"}>
        <SettingCard icon="solar:shield-warning-bold-duotone" title="违禁词与广告关键词" description="白名单优先于违禁词；全部处理都会留下审核记录。"><Toggle label="开启关键词拦截" checked={props.forbiddenEnabled} onChange={props.setForbiddenEnabled} /><Toggle label="开启 24 小时阶梯处罚" checked={props.escalationEnabled} onChange={props.setEscalationEnabled} /><p class="text-xs leading-5 text-emerald-950/50">打开后，同一用户第 2 次命中禁言 10 分钟，第 3 次禁言 1 小时，之后封禁；默认关闭。</p><textarea class={inputClass} rows="3" value={props.warningText} onInput={(event) => props.setWarningText(event.currentTarget.value)} placeholder="消息包含违禁词，已自动删除。" /><NumberField label="提示消息删除延时（秒）" value={props.warningDeleteAfter} onInput={props.setWarningDeleteAfter} /><div class="grid gap-2 sm:grid-cols-[1fr_8rem]" ><input class={inputClass} value={word()} onInput={(event) => setWord(event.currentTarget.value)} placeholder="添加关键词" /><select class={inputClass} value={wordMode()} onChange={(event) => setWordMode(event.currentTarget.value as InputData.ForbiddenWord["match_mode"])}><option value="contains">包含</option><option value="exact">完全匹配</option><option value="prefix">前缀匹配</option></select></div><div class="grid gap-2 sm:grid-cols-[1fr_auto]" ><select class={inputClass} value={wordAction()} onChange={(event) => setWordAction(event.currentTarget.value as InputData.ForbiddenWord["action"])}><option value="delete_warn">删除并提示</option><option value="mute_10m">删除并禁言 10 分钟</option><option value="mute_1h">删除并禁言 1 小时</option><option value="ban">删除并封禁</option></select><ActionButton variant="info" onClick={addWord}>添加关键词</ActionButton></div><input class={inputClass} value={wordWarning()} onInput={(event) => setWordWarning(event.currentTarget.value)} placeholder="该词专用提示（可选）" /><div class="space-y-2"><For each={props.words}>{(item) => <div class="flex items-center justify-between gap-3 rounded-xl bg-tea-50 px-3 py-2 text-sm"><span class="min-w-0 truncate">{item.word}<small class="ml-1 text-emerald-950/45">· {actionText(item.action)}</small></span><ActionButton variant="danger" size="sm" onClick={() => props.onRemoveWord(item.id)}>删除</ActionButton></div>}</For></div></SettingCard>
        <SettingCard icon="solar:check-circle-bold-duotone" title="白名单与处理记录" description="白名单命中时不触发关键词拦截。"><div class="grid gap-2 sm:grid-cols-[1fr_auto]"><input class={inputClass} value={whiteWord()} onInput={(event) => setWhiteWord(event.currentTarget.value)} placeholder="例如：可信域名或品牌词" /><ActionButton variant="info" onClick={addWhitelist}>加入白名单</ActionButton></div><div class="space-y-2"><For each={props.whitelist}>{(item) => <div class="flex items-center justify-between gap-3 rounded-xl bg-tea-50 px-3 py-2 text-sm"><span class="truncate">{item.word}</span><ActionButton variant="danger" size="sm" onClick={() => props.onRemoveWhitelist(item.id)}>删除</ActionButton></div>}</For></div><div class="flex items-center justify-between"><p class="text-sm font-bold text-ink">最近处理记录</p><ActionButton variant="info" outline size="sm" onClick={() => props.onRefreshEvents()}>刷新</ActionButton></div><Show when={props.events.length > 0} fallback={<p class="panel-muted rounded-xl bg-tea-50 p-3 text-center">暂无处理记录</p>}><div class="max-h-72 space-y-2 overflow-y-auto"><For each={props.events}>{(event) => <div class="rounded-xl border border-emerald-950/8 p-3 text-xs"><div class="flex items-center justify-between gap-3"><strong>{event.ruleWord}</strong><span class={event.status === "applied" ? "text-tea-600" : "text-amber-700"}>{event.status === "applied" ? actionText(event.action) : "处理未完成"}</span></div><p class="mt-1 text-emerald-950/50">用户 ID {event.userId ?? "未知"} · {new Date(event.insertedAt).toLocaleString()}</p></div>}</For></div></Show></SettingCard>
      </Show>
      <Show when={props.activeCategory === "schedules"}>
        <div class="xl:col-span-2"><SettingCard icon="solar:calendar-add-bold-duotone" title={editingScheduleId() === null ? "定时群消息" : "编辑定时群消息"} description="创建、编辑、暂停和试发群消息；所有操作只作用于当前群组。"><input class={inputClass} value={scheduleTitle()} onInput={(event) => setScheduleTitle(event.currentTarget.value)} placeholder="任务名称" /><textarea class={inputClass} rows="4" value={scheduleText()} onInput={(event) => setScheduleText(event.currentTarget.value)} placeholder="要发送到群里的内容" /><div class="grid gap-3 sm:grid-cols-2"><label class="panel-muted">发送时间<input class={inputClass + " mt-1"} type="datetime-local" value={scheduleAt()} onInput={(event) => setScheduleAt(event.currentTarget.value)} /></label><NumberField label="后续消息删除延时（秒）" value={scheduleDeleteAfter()} onInput={setScheduleDeleteAfter} /></div><Toggle label="保留第一次发送的消息" checked={preserveFirst()} onChange={setPreserveFirst} /><div class="flex flex-wrap gap-2"><ActionButton variant="info" loading={scheduleSaving()} onClick={saveSchedule}>{editingScheduleId() === null ? "新增定时消息" : "保存定时消息"}</ActionButton><Show when={editingScheduleId() !== null}><ActionButton outline onClick={resetSchedule}>取消编辑</ActionButton></Show></div><div class="space-y-2"><For each={props.schedules}>{(item) => <div class="rounded-xl bg-tea-50 p-3"><div class="flex flex-wrap items-center justify-between gap-3"><strong class="min-w-0 truncate text-sm">{item.title}</strong><span class={item.enabled ? "rounded-full bg-emerald-100 px-2 py-1 text-xs font-bold text-emerald-700" : "rounded-full bg-slate-200 px-2 py-1 text-xs font-bold text-slate-600"}>{item.enabled ? "已启用" : "已暂停"}</span></div><p class="mt-1 line-clamp-2 text-sm text-emerald-950/65">{item.text}</p><p class="mt-2 text-xs text-emerald-950/45">下次发送：{new Date(item.nextRunAt).toLocaleString()} · 已发送 {item.sentCount} 次</p><div class="mt-3 flex flex-wrap gap-2"><ActionButton variant="info" outline size="sm" onClick={() => editSchedule(item)}>编辑</ActionButton><ActionButton variant="info" size="sm" loading={scheduleActionId() === item.id} onClick={() => runScheduleAction(item, "toggle")}>{item.enabled ? "暂停" : "恢复"}</ActionButton><ActionButton variant="info" outline size="sm" loading={scheduleActionId() === item.id} onClick={() => runScheduleAction(item, "test")}>试发</ActionButton><ActionButton variant="danger" size="sm" onClick={() => removeSchedule(item)}>删除</ActionButton></div><Show when={item.lastError}><p class="mt-2 rounded-lg bg-amber-50 px-2 py-1 text-xs text-amber-800">上次发送失败，已自动重试：{item.lastError}</p></Show></div>}</For></div></SettingCard></div>
      </Show>
    </div>
    </fieldset>
  </div>;
};

const messageCategories: { id: MessageCategory; label: string; hint: string; icon: string }[] = [
  { id: "settings", label: "消息设置", hint: "删除与欢迎", icon: "solar:settings-bold-duotone" },
  { id: "templates", label: "机器人文案", hint: "当前发言", icon: "solar:chat-round-dots-bold-duotone" },
  { id: "replies", label: "自动回复", hint: "关键词与按钮", icon: "solar:chat-square-arrow-bold-duotone" },
  { id: "moderation", label: "违禁词", hint: "规则与记录", icon: "solar:shield-warning-bold-duotone" },
  { id: "schedules", label: "定时消息", hint: "自动发送", icon: "solar:calendar-bold-duotone" },
];

const MessageCategorySwitcher = (props: { active: MessageCategory; templateCount: number; onChange: (value: MessageCategory) => void }) => (
  <nav class="grid grid-cols-2 gap-2 rounded-2xl border border-emerald-950/8 bg-white p-2 shadow-sm sm:grid-cols-3 lg:grid-cols-5">
    <For each={messageCategories}>{(item) => <button type="button" onClick={() => props.onChange(item.id)} class={props.active === item.id ? "flex min-w-0 items-center gap-2.5 rounded-xl bg-tea-600 px-3 py-3 text-left text-white shadow-sm" : "flex min-w-0 items-center gap-2.5 rounded-xl px-3 py-3 text-left text-emerald-950/60 transition hover:bg-tea-50"}><Icon icon={item.icon} class="shrink-0 text-2xl" /><span class="min-w-0"><strong class="block truncate text-sm">{item.label}</strong><small class={props.active === item.id ? "block truncate text-[11px] text-white/75" : "block truncate text-[11px] text-emerald-950/40"}>{item.id === "templates" && props.templateCount > 0 ? `${props.templateCount} 条文案` : item.hint}</small></span></button>}</For>
  </nav>
);

const actionText = (action: string) => ({ delete_warn: "删除并提示", mute_10m: "禁言 10 分钟", mute_1h: "禁言 1 小时", ban: "封禁" }[action] || action);
function defaultScheduleTime() { const date = new Date(Date.now() + 60_000); const pad = (value: number) => String(value).padStart(2, "0"); return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`; }
function toLocalDateTime(value: string) { const date = new Date(value); const pad = (part: number) => String(part).padStart(2, "0"); return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`; }
