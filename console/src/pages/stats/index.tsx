import { Icon } from "@iconify-icon/solid";
import { destructure } from "@solid-primitives/destructure";
import { A } from "@solidjs/router";
import { useQuery } from "@tanstack/solid-query";
import { createSignal, For, onMount, Show } from "solid-js";
import { getChatHealth, queryStats } from "../../api";
import { Range } from "../../components";
import { PageBase } from "../../layouts";
import { globalState } from "../../state";
import { setCurrentPage } from "../../state/global";
import { setTitle } from "../../state/meta";
import AreaChart from "./AreaChart";
import TotalsView from "./TotalsView";

const DEFAULT_RANGE = "7d";
const RANGE_ITEMS: Array<{ value: InputData.StatsRange; label: string }> = [
  { value: "today", label: "今天" },
  { value: "7d", label: "最近 7 天" },
  { value: "28d", label: "最近 28 天" },
  { value: "90d", label: "最近 90 天" },
];

const shortcuts = [
  { href: "/security", icon: "solar:shield-check-bold-duotone", title: "安全防护", text: "入群验证、广告和违禁词", tag: "优先检查" },
  { href: "/messages", icon: "solar:chat-round-dots-bold-duotone", title: "群消息自动化", text: "欢迎语、删除和定时发送", tag: "消息中心" },
  { href: "/members", icon: "solar:users-group-rounded-bold-duotone", title: "成员管理", text: "搜索成员、永久拉黑与解除", tag: "群组管理" },
  { href: "/lottery", icon: "solar:gift-bold-duotone", title: "抽奖活动", text: "奖品设置、关键词和开奖", tag: "活动中心" },
  { href: "/permissions", icon: "solar:key-minimalistic-square-3-bold-duotone", title: "权限管理", text: "管理员访问、执行与配置授权", tag: "群主设置" },
  { href: "/logs", icon: "solar:history-bold-duotone", title: "操作记录", text: "验证结果与历史操作", tag: "审计记录" },
];

export default () => {
  const { currentChatId, currentChatTitle } = destructure(globalState);
  const avatarVersion = Date.now();
  const [range, setRange] = createSignal<InputData.StatsRange>(DEFAULT_RANGE);
  const query = useQuery(() => ({
    queryKey: ["stats", currentChatId(), range()],
    queryFn: () => queryStats(currentChatId()!, range()),
    enabled: () => currentChatId() != null,
  }));
  const healthQuery = useQuery(() => ({
    queryKey: ["chat-health", currentChatId()],
    queryFn: () => getChatHealth(currentChatId()!),
    enabled: () => currentChatId() != null,
    refetchInterval: 120_000,
  }));
  const health = () => healthQuery.data?.success ? healthQuery.data.payload : undefined;
  const healthy = () => health()?.status === "healthy";
  const statusText = () => {
    if (healthQuery.isLoading) return "检查中";
    if (!health()) return "暂不可用";
    return healthy() ? "运行正常" : "需要处理";
  };
  const missingText = () => health()?.lastAudit.missingPermissions.map(permissionLabel).join("、") || "无";

  onMount(() => {
    setCurrentPage("stats");
    setTitle("工作台");
  });

  return (
    <PageBase>
      <div class="mx-auto max-w-6xl space-y-5">
        <section class="relative overflow-hidden rounded-[2rem] border border-[#2f6c59] bg-[#173d31] text-white shadow-[0_20px_55px_rgba(23,61,49,0.18)]">
          <div class="absolute -right-20 -top-24 h-64 w-64 rounded-full bg-[#6fae86]/20 blur-2xl" />
          <div class="absolute -bottom-24 left-1/3 h-48 w-48 rounded-full bg-[#d9b86c]/10 blur-3xl" />
          <div class="relative grid gap-6 p-5 sm:p-7 lg:grid-cols-[1.25fr_0.75fr] lg:gap-10 lg:p-9">
            <div>
              <div class="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-3 py-1.5 text-[0.68rem] font-bold uppercase tracking-[0.16em] text-white/80">
                <span class="h-1.5 w-1.5 rounded-full bg-[#a8d9b3]" /> WUFENG CONSOLE
              </div>
              <p class="mt-6 text-sm font-semibold text-[#b8d8c1]">WuFengBot 群组控制中心</p>
              <h1 class="mt-2 max-w-xl text-3xl font-black leading-tight tracking-tight sm:text-4xl">让群组管理，<span class="text-[#b8d8c1]">清晰而可靠。</span></h1>
              <p class="mt-4 max-w-xl text-sm leading-6 text-white/65">把验证、防护、群消息和抽奖集中在一个工作台中，选择群组后即可开始管理。</p>
              <div class="mt-6 flex max-w-md items-center gap-3 rounded-2xl border border-white/10 bg-white/10 p-3">
                <Show
                  when={currentChatId()}
                  fallback={<div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-white/15 text-[#b8d8c1]"><Icon icon="solar:users-group-rounded-bold-duotone" class="text-[1.4rem]" /></div>}
                >
                  <img src={`/console/v2/${currentChatId()}/photo?v=${avatarVersion}`} alt="当前管理群组头像" class="h-10 w-10 shrink-0 rounded-xl border border-white/20 object-cover shadow-sm" />
                </Show>
                <div class="min-w-0"><p class="text-[0.68rem] font-semibold text-white/50">当前管理群组</p><p class="truncate text-sm font-bold">{currentChatTitle() || "尚未选择群组"}</p></div>
                <Show when={currentChatTitle()}><span class="ml-auto shrink-0 rounded-full bg-[#a8d9b3]/15 px-2 py-1 text-[0.65rem] font-bold text-[#b8d8c1]">管理中</span></Show>
              </div>
            </div>
            <div class="flex flex-col justify-between rounded-3xl border border-white/10 bg-black/10 p-5 sm:p-6">
              <div class="flex items-start justify-between"><div><p class="text-xs font-semibold text-white/50">系统状态</p><p class="mt-2 text-2xl font-black">{statusText()}</p></div><div class={healthy() ? "flex h-12 w-12 items-center justify-center rounded-2xl bg-[#a8d9b3]/15 text-[#b8d8c1]" : "flex h-12 w-12 items-center justify-center rounded-2xl bg-amber-300/15 text-amber-200"}><Icon icon={healthy() ? "solar:shield-check-bold-duotone" : "solar:shield-warning-bold-duotone"} class="text-[1.8rem]" /></div></div>
              <div class="mt-8 space-y-3 text-sm"><div class="flex items-center justify-between text-white/60"><span>机器人连接</span><span class={health()?.bot.initialized ? "font-bold text-[#b8d8c1]" : "font-bold text-amber-200"}>{health()?.bot.initialized ? "已初始化" : "未确认"}</span></div><div class="h-px bg-white/10" /><div class="flex items-center justify-between text-white/60"><span>权限巡检</span><span class={healthy() ? "font-bold text-[#b8d8c1]" : "font-bold text-amber-200"}>{health() ? missingText() : "等待检查"}</span></div><div class="h-px bg-white/10" /><div class="flex items-center justify-between text-white/60"><span>自动化异常</span><span class={(health()?.automation.failedDeleteJobs || health()?.automation.failedSchedules) ? "font-bold text-amber-200" : "font-bold text-[#b8d8c1]"}>{health() ? `${health()!.automation.failedDeleteJobs + health()!.automation.failedSchedules} 项` : "—"}</span></div></div>
              <div class="mt-6 flex gap-2"><button type="button" onClick={() => healthQuery.refetch()} class="flex flex-1 items-center justify-center gap-2 rounded-2xl border border-white/15 px-4 py-3 text-sm font-bold text-white/80 transition hover:bg-white/10">重新巡检</button><A href="/security" class="flex flex-1 items-center justify-center gap-2 rounded-2xl bg-[#b8d8c1] px-4 py-3 text-sm font-bold text-[#173d31] transition hover:bg-white">安全设置 <Icon icon="solar:arrow-right-up-linear" class="text-lg" /></A></div>
            </div>
          </div>
        </section>

        <section>
          <div class="mb-3 flex items-center justify-between">
            <div>
              <div class="flex items-center gap-2"><span class="h-2 w-2 rounded-full bg-tea-500" /><h2 class="panel-page-title text-xl">常用管理</h2></div>
              <p class="panel-muted mt-1">从这里开始配置你的群组</p>
            </div>
            <span class="hidden rounded-full bg-white px-3 py-1.5 text-xs font-semibold text-emerald-950/45 shadow-sm sm:inline">6 个核心模块</span>
          </div>
          <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            <For each={shortcuts}>
              {(item) => (
                <A href={item.href} class="panel-card group flex min-h-[9.5rem] flex-col justify-between p-4 transition hover:-translate-y-1 hover:border-tea-500/35 hover:shadow-lg sm:p-5">
                  <div class="flex items-start justify-between"><span class="flex h-11 w-11 items-center justify-center rounded-2xl bg-tea-100 text-tea-600 transition group-hover:bg-tea-600 group-hover:text-white"><Icon icon={item.icon} class="text-[1.5rem]" /></span><Icon icon="solar:arrow-up-right-linear" class="text-xl text-emerald-950/25 transition group-hover:translate-x-0.5 group-hover:-translate-y-0.5 group-hover:text-tea-600" /></div>
                  <span class="mt-5 min-w-0"><span class="mb-1 block text-[0.65rem] font-bold uppercase tracking-[0.12em] text-tea-600">{item.tag}</span><strong class="block text-sm text-ink">{item.title}</strong><small class="mt-1 block truncate text-xs text-emerald-950/55">{item.text}</small></span>
                </A>
              )}
            </For>
          </div>
        </section>

        <section class="panel-card p-4 sm:p-5">
          <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div><h2 class="panel-section-title"><Icon icon="solar:chart-2-bold-duotone" class="text-xl text-tea-600" />验证概览</h2><p class="panel-muted">按时间查看入群验证结果</p></div>
            <Range.List items={RANGE_ITEMS}>{(item) => <Range.Item value={item.value} label={item.label} active={range() === item.value} onClick={setRange} />}</Range.List>
          </div>
          <TotalsView status={query.data?.success && query.data.payload} />
          <AreaChart range={range()} stats={query.data?.success && query.data.payload} />
        </section>
      </div>
    </PageBase>
  );
};

function permissionLabel(permission: string) {
  return ({ administrator: "管理员", send_messages: "发送消息", delete_messages: "删除消息", restrict_members: "限制成员", pin_messages: "置顶消息" }[permission] || permission);
}
