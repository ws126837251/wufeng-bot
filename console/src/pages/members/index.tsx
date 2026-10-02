import { Icon } from "@iconify-icon/solid";
import { destructure } from "@solid-primitives/destructure";
import { useQuery } from "@tanstack/solid-query";
import { createEffect, createSignal, For, onMount, Show } from "solid-js";
import { blacklistMember, getMemberActions, getMemberBlacklist, getMembers, getMemberSync, isApprovalPending, syncMembers, unblockMember } from "../../api";
import { PageBase } from "../../layouts";
import { globalState } from "../../state";
import { setCurrentPage } from "../../state/global";
import { setTitle } from "../../state/meta";
import { toaster } from "../../utils";

export default () => {
  const { currentChatId, currentChatTitle, currentChatCanOperate } = destructure(globalState);
  const [input, setInput] = createSignal("");
  const [queryText, setQueryText] = createSignal("");
  const [selected, setSelected] = createSignal<ServerData.Member | null>(null);
  const [reason, setReason] = createSignal("");
  const [kicking, setKicking] = createSignal(false);
  const [unblockingId, setUnblockingId] = createSignal<number | null>(null);
  const [startingSync, setStartingSync] = createSignal(false);

  const membersQuery = useQuery(() => ({
    queryKey: ["members", currentChatId(), queryText()],
    queryFn: () => getMembers(currentChatId()!, queryText()),
    enabled: () => currentChatId() != null,
  }));
  const actionsQuery = useQuery(() => ({
    queryKey: ["member-actions", currentChatId()],
    queryFn: () => getMemberActions(currentChatId()!),
    enabled: () => currentChatId() != null,
  }));
  const blacklistQuery = useQuery(() => ({
    queryKey: ["member-blacklist", currentChatId()],
    queryFn: () => getMemberBlacklist(currentChatId()!),
    enabled: () => currentChatId() != null,
  }));
  const syncQuery = useQuery(() => ({
    queryKey: ["member-sync", currentChatId()],
    queryFn: () => getMemberSync(currentChatId()!),
    enabled: () => currentChatId() != null,
    refetchInterval: 4000,
  }));
  const members = () => membersQuery.data?.success && membersQuery.data.payload.every((member) => member.chatId === currentChatId()) ? membersQuery.data.payload : [];
  const actions = () => actionsQuery.data?.success ? actionsQuery.data.payload : [];
  const blacklist = () => blacklistQuery.data?.success ? blacklistQuery.data.payload : [];
  const syncState = () => syncQuery.data?.success ? syncQuery.data.payload : null;
  let previousSyncStatus: ServerData.MemberSync["status"] | null = null;

  createEffect(() => {
    const status = syncState()?.status || null;
    if (previousSyncStatus === "running" && status === "success") membersQuery.refetch();
    previousSyncStatus = status;
  });

  createEffect(() => {
    currentChatId();
    setSelected(null);
    setReason("");
    setInput("");
    setQueryText("");
  });

  onMount(() => {
    setCurrentPage("members");
    setTitle("成员管理");
  });

  const search = (event: SubmitEvent) => {
    event.preventDefault();
    setQueryText(input().trim());
  };

  const startSync = async () => {
    const chatId = currentChatId();
    if (!chatId || startingSync()) return;
    setStartingSync(true);
    try {
      const response = await syncMembers(chatId);
      if (isApprovalPending(response)) return;
      if (response.success) {
        toaster.success({ title: "全成员同步已开始", description: "机器人正在读取当前群的完整成员名单。" });
        await syncQuery.refetch();
      } else {
        toaster.error({ title: "同步未启动", description: response.message, duration: 5_000 });
      }
    } catch (error) {
      toaster.error({ title: "同步启动失败", description: error instanceof Error ? error.message : "请稍后重试" });
    } finally {
      setStartingSync(false);
    }
  };

  const confirmKick = async () => {
    const member = selected();
    const chatId = currentChatId();
    if (!member || !chatId || kicking()) return;
    setKicking(true);
    try {
      const response = await blacklistMember(chatId, member.userId, reason().trim());
      if (isApprovalPending(response)) {
        setSelected(null);
        setReason("");
        return;
      }
      if (response.success) {
        toaster.success({ title: "已加入黑名单", description: `${member.fullName} 已被永久移出，并会被拒绝再次入群。` });
        setSelected(null);
        setReason("");
        await Promise.all([membersQuery.refetch(), blacklistQuery.refetch(), actionsQuery.refetch()]);
      } else {
        toaster.error({ title: "拉黑未执行", description: response.message, duration: 5_000 });
      }
    } catch (error) {
      toaster.error({ title: "拉黑失败", description: error instanceof Error ? error.message : "请稍后重试" });
    } finally {
      setKicking(false);
    }
  };

  const unblock = async (entry: ServerData.MemberBlacklistEntry) => {
    const chatId = currentChatId();
    if (!chatId || unblockingId() != null) return;
    if (!window.confirm(`确认解除 ${entry.fullName} 的黑名单？解除后对方可以再次申请或加入当前群组。`)) return;
    setUnblockingId(entry.userId);
    try {
      const response = await unblockMember(chatId, entry.userId);
      if (isApprovalPending(response)) return;
      if (response.success) {
        toaster.success({ title: "黑名单已解除", description: `${entry.fullName} 现在可以重新加入群组。` });
        await Promise.all([membersQuery.refetch(), blacklistQuery.refetch(), actionsQuery.refetch()]);
      } else {
        toaster.error({ title: "解除未执行", description: response.message, duration: 5_000 });
      }
    } catch (error) {
      toaster.error({ title: "解除失败", description: error instanceof Error ? error.message : "请稍后重试" });
    } finally {
      setUnblockingId(null);
    }
  };

  return (
    <PageBase>
      <div class="mx-auto max-w-6xl space-y-5">
        <section class="relative overflow-hidden rounded-[2rem] bg-[#173d31] p-5 text-white shadow-[0_20px_55px_rgba(23,61,49,0.16)] sm:p-7">
          <div class="absolute -right-12 -top-16 h-48 w-48 rounded-full bg-[#79b990]/15 blur-2xl" />
          <div class="relative flex flex-col gap-5 md:flex-row md:items-end md:justify-between">
            <div>
              <div class="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-3 py-1.5 text-[0.68rem] font-bold uppercase tracking-[0.16em] text-white/75">
                <Icon icon="solar:users-group-rounded-bold-duotone" class="text-base" /> MEMBER CONTROL
              </div>
              <h1 class="mt-4 text-2xl font-black sm:text-3xl">成员管理</h1>
              <p class="mt-2 max-w-2xl text-sm leading-6 text-white/65">同步并搜索当前群的完整成员名单，主动拉黑后由 WuFengBot 永久移出并拒绝再次入群。</p>
            </div>
            <div class="rounded-2xl border border-white/10 bg-white/10 px-4 py-3 md:min-w-60">
              <p class="text-[0.68rem] font-semibold text-white/50">当前群组</p>
              <p class="mt-1 truncate text-sm font-bold">{currentChatTitle() || "尚未选择群组"}</p>
              <p class="mt-1 text-xs font-semibold text-[#b8d8c1]">{currentChatCanOperate() ? "可执行成员操作" : "当前账号仅可查看"}</p>
            </div>
          </div>
        </section>

        <section class="panel-card p-4 sm:p-5">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h2 class="panel-section-title"><Icon icon="solar:users-group-two-rounded-bold-duotone" class="text-xl text-tea-600" />全群成员同步</h2>
              <p class="panel-muted mt-1">通过 WuFengBot 读取当前群完整成员名单，每天自动同步一次。</p>
            </div>
            <button type="button" onClick={startSync} disabled={!currentChatCanOperate() || startingSync() || syncState()?.status === "running"} class="h-11 shrink-0 rounded-2xl bg-tea-600 px-5 text-sm font-bold text-white shadow-sm disabled:cursor-not-allowed disabled:opacity-45">
              {syncState()?.status === "running" ? "正在同步…" : startingSync() ? "正在启动…" : "立即同步全部成员"}
            </button>
          </div>
          <div class="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
            <SyncMetric label="Telegram成员" value={syncState()?.telegramCount || 0} />
            <SyncMetric label="当前已索引" value={syncState()?.indexedCount || 0} />
            <SyncMetric label="同步状态" value={syncStatusLabel(syncState()?.status)} />
            <SyncMetric label="上次完成" value={syncState()?.lastCompletedAt ? formatTime(syncState()!.lastCompletedAt!) : "尚未同步"} />
          </div>
          <Show when={syncState()?.lastError}><div class="mt-3 rounded-2xl bg-red-50 px-4 py-3 text-xs leading-5 text-red-600">同步失败：{syncState()!.lastError}</div></Show>
        </section>

        <section class="panel-card p-4 sm:p-5">
          <div class="flex flex-col gap-1">
            <h2 class="panel-section-title"><Icon icon="solar:magnifer-bold-duotone" class="text-xl text-tea-600" />搜索成员</h2>
            <p class="panel-muted">可搜索机器人已记录的姓名、@用户名或 Telegram 数字 ID。</p>
          </div>
          <form onSubmit={search} class="mt-4 flex flex-col gap-3 sm:flex-row">
            <div class="relative flex-1">
              <Icon icon="solar:magnifer-linear" class="absolute left-4 top-1/2 -translate-y-1/2 text-xl text-emerald-950/35" />
              <input value={input()} onInput={(event) => setInput(event.currentTarget.value)} placeholder="输入姓名、@username 或数字ID" class="h-13 w-full rounded-2xl border border-emerald-950/10 bg-[#fbfcfa] pl-12 pr-4 text-sm text-ink outline-none transition focus:border-tea-500/45 focus:ring-4 focus:ring-tea-100" />
            </div>
            <button type="submit" class="h-13 rounded-2xl bg-tea-600 px-6 text-sm font-bold text-white shadow-sm transition hover:bg-tea-700">搜索成员</button>
          </form>
          <div class="mt-4 flex items-start gap-2 rounded-2xl bg-tea-50 px-4 py-3 text-xs leading-5 text-tea-800">
            <Icon icon="solar:info-circle-bold-duotone" class="mt-0.5 shrink-0 text-lg" />
            <p>完成全群成员同步后，搜索范围就是当前群的完整成员名单；新成员与离群状态也会持续更新。</p>
          </div>
        </section>

        <section class="panel-card overflow-hidden">
          <div class="border-b border-emerald-950/8 p-4 sm:p-5">
            <div class="flex items-center justify-between gap-3">
              <div><h2 class="panel-section-title"><Icon icon="solar:shield-warning-bold-duotone" class="text-xl text-red-500" />群组黑名单</h2><p class="panel-muted mt-1">名单内用户会被永久移出，入群申请和重新加入都会被拒绝。</p></div>
              <span class="rounded-full bg-red-50 px-3 py-1.5 text-xs font-bold text-red-600">{blacklist().length} 人</span>
            </div>
          </div>
          <div class="grid gap-3 p-4 sm:p-5 lg:grid-cols-2">
            <Show when={!blacklistQuery.isLoading} fallback={<EmptyState text="正在读取黑名单…" />}>
              <For each={blacklist()} fallback={<EmptyState text="当前群组暂无黑名单成员" />}>
                {(entry) => (
                  <article class="flex items-center gap-3 rounded-3xl border border-red-100 bg-red-50/45 p-4">
                    <img src={entry.photoUrl} alt={entry.fullName} class="h-12 w-12 shrink-0 rounded-2xl bg-red-100 object-cover" />
                    <div class="min-w-0 flex-1"><p class="truncate text-sm font-bold text-ink">{entry.fullName}</p><p class="mt-1 truncate text-xs text-emerald-950/45">{entry.username ? `@${entry.username}` : `ID ${entry.userId}`} · {formatTime(entry.insertedAt)}</p><Show when={entry.reason}><p class="mt-1 truncate text-xs text-red-600/75">原因：{entry.reason}</p></Show><Show when={entry.lastError}><p class="mt-1 truncate text-xs text-amber-600">Telegram执行重试中</p></Show></div>
                    <button type="button" disabled={!currentChatCanOperate() || unblockingId() != null} onClick={() => unblock(entry)} class="shrink-0 rounded-xl bg-white px-3 py-2 text-xs font-bold text-tea-700 shadow-sm disabled:cursor-not-allowed disabled:opacity-35">{unblockingId() === entry.userId ? "解除中…" : "解除"}</button>
                  </article>
                )}
              </For>
            </Show>
          </div>
        </section>

        <section class="panel-card overflow-hidden">
          <div class="border-b border-emerald-950/8 p-4 sm:p-5">
            <div class="flex items-center justify-between gap-3">
              <div><h2 class="panel-section-title">搜索结果</h2><p class="panel-muted mt-1">执行前会再次检查成员和机器人权限</p></div>
              <span class="rounded-full bg-tea-50 px-3 py-1.5 text-xs font-bold text-tea-600">{members().length} 人</span>
            </div>
          </div>
          <div class="grid gap-3 p-4 sm:p-5 lg:grid-cols-2">
            <Show when={!membersQuery.isLoading} fallback={<EmptyState text="正在读取成员…" />}>
              <For each={members()} fallback={<EmptyState text={queryText() ? "当前群完整成员中没有找到匹配结果" : "请先同步当前群的完整成员名单"} />}>
                {(member) => <MemberCard member={member} canOperate={currentChatCanOperate()} onKick={() => { setSelected(member); setReason(""); }} />}
              </For>
            </Show>
          </div>
        </section>

        <section class="panel-card overflow-hidden">
          <div class="border-b border-emerald-950/8 p-4 sm:p-5"><h2 class="panel-section-title"><Icon icon="solar:history-bold-duotone" class="text-xl text-tea-600" />最近成员操作</h2></div>
          <div class="divide-y divide-emerald-950/6 px-4 sm:px-5">
            <For each={actions().slice(0, 15)} fallback={<div class="py-8 text-center text-sm text-emerald-950/40">暂无成员操作记录</div>}>
              {(action) => (
                <div class="flex items-start gap-3 py-4">
                  <span class={action.status === "success" ? "flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-emerald-100 text-emerald-700" : "flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-red-100 text-red-600"}><Icon icon={action.status === "success" ? "solar:user-minus-rounded-bold-duotone" : "solar:danger-triangle-bold-duotone"} class="text-xl" /></span>
                  <div class="min-w-0 flex-1"><p class="truncate text-sm font-bold text-ink">{action.targetDisplayName || `用户 ${action.targetUserId}`}</p><p class="mt-1 text-xs text-emerald-950/45">{action.status === "success" ? (action.action === "unblock" ? "解除黑名单成功" : "拉黑成功") : `执行失败：${action.telegramError || "未知错误"}`} · {formatTime(action.insertedAt)}</p><Show when={action.reason}><p class="mt-1 truncate text-xs text-emerald-950/55">原因：{action.reason}</p></Show></div>
                </div>
              )}
            </For>
          </div>
        </section>
      </div>

      <Show when={selected()}>
        <div class="fixed inset-0 z-[80] flex items-end justify-center bg-emerald-950/45 p-3 backdrop-blur-sm sm:items-center" onClick={() => !kicking() && setSelected(null)}>
          <div class="w-full max-w-md rounded-[2rem] bg-white p-5 shadow-2xl sm:p-6" onClick={(event) => event.stopPropagation()}>
            <div class="flex items-start gap-3"><img src={selected()!.photoUrl} class="h-12 w-12 rounded-2xl bg-emerald-950/5 object-cover" /><div class="min-w-0 flex-1"><p class="text-xs font-bold text-red-500">确认加入黑名单</p><h3 class="mt-1 truncate text-xl font-black text-ink">{selected()!.fullName}</h3><p class="mt-1 text-xs text-emerald-950/45">{selected()!.username ? `@${selected()!.username}` : `ID ${selected()!.userId}`}</p></div><button type="button" onClick={() => setSelected(null)} class="flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-950/5 text-emerald-950/50"><Icon icon="solar:close-circle-linear" class="text-xl" /></button></div>
            <label class="mt-5 block text-sm font-bold text-ink">处理原因（选填）</label>
            <textarea value={reason()} onInput={(event) => setReason(event.currentTarget.value.slice(0, 200))} rows={3} placeholder="例如：持续发布广告" class="mt-2 w-full resize-none rounded-2xl border border-emerald-950/10 bg-[#fbfcfa] p-3 text-sm outline-none focus:border-tea-500/45 focus:ring-4 focus:ring-tea-100" />
            <p class="mt-2 text-xs leading-5 text-red-600/75">该操作会永久移出此成员，并拒绝其以后再次申请或加入当前群组。只有从黑名单列表解除后才能重新加入。</p>
            <div class="mt-5 grid grid-cols-2 gap-3"><button type="button" disabled={kicking()} onClick={() => setSelected(null)} class="rounded-2xl border border-emerald-950/10 px-4 py-3 text-sm font-bold text-emerald-950/60">取消</button><button type="button" disabled={kicking()} onClick={confirmKick} class="rounded-2xl bg-red-500 px-4 py-3 text-sm font-bold text-white shadow-sm disabled:opacity-50">{kicking() ? "正在执行…" : "确认拉黑"}</button></div>
          </div>
        </div>
      </Show>
    </PageBase>
  );
};

const MemberCard = (props: { member: ServerData.Member; canOperate: boolean; onKick: () => void }) => {
  const disabled = () => !props.canOperate || !props.member.removable;
  return (
    <article class="flex items-center gap-3 rounded-3xl border border-emerald-950/8 bg-[#fbfcfa] p-4">
      <img src={props.member.photoUrl} alt={props.member.fullName} class="h-12 w-12 shrink-0 rounded-2xl bg-emerald-950/5 object-cover" />
      <div class="min-w-0 flex-1"><div class="flex items-center gap-2"><p class="truncate text-sm font-bold text-ink">{props.member.fullName}</p><span class="shrink-0 rounded-full bg-emerald-950/5 px-2 py-0.5 text-[0.62rem] font-bold text-emerald-950/50">{statusLabel(props.member.status)}</span></div><p class="mt-1 truncate text-xs text-emerald-950/45">{props.member.username ? `@${props.member.username}` : `ID ${props.member.userId}`} · {sourceLabel(props.member.source)}</p></div>
      <button type="button" disabled={disabled()} onClick={props.onKick} class="shrink-0 rounded-xl bg-red-50 px-3 py-2 text-xs font-bold text-red-600 transition hover:bg-red-100 disabled:cursor-not-allowed disabled:opacity-35">拉黑</button>
    </article>
  );
};

const EmptyState = (props: { text: string }) => <div class="col-span-full rounded-2xl bg-emerald-950/4 px-4 py-9 text-center text-sm font-semibold text-emerald-950/45">{props.text}</div>;
const SyncMetric = (props: { label: string; value: string | number }) => <div class="rounded-2xl bg-emerald-950/4 px-4 py-3"><p class="text-[0.65rem] font-bold text-emerald-950/40">{props.label}</p><p class="mt-1 truncate text-sm font-black text-ink">{props.value}</p></div>;
const STATUS_LABELS: Record<string, string> = { creator: "群主", administrator: "管理员", member: "群成员", restricted: "受限", unknown: "待核验", left: "已离开", kicked: "已踢出" };
const SOURCE_LABELS: Record<string, string> = { full_sync: "完整成员同步", administrator: "管理员记录", verification: "验证记录", lottery: "抽奖记录", message: "群消息", reply_target: "回复识别", callback: "机器人互动", join_request: "入群申请", member_update: "成员事件", direct_lookup: "数字ID核验", known_username_lookup: "用户名核验", username_lookup: "公开账号核验", member_blacklist: "手动拉黑" };
const syncStatusLabel = (status?: ServerData.MemberSync["status"]) => ({ idle: "待同步", running: "同步中", success: "已完成", failed: "失败" })[status || "idle"];
const statusLabel = (status: string) => STATUS_LABELS[status] || status;
const sourceLabel = (source: string) => SOURCE_LABELS[source] || "机器人记录";
const formatTime = (value: string) => new Date(value).toLocaleString("zh-CN", { hour12: false });
