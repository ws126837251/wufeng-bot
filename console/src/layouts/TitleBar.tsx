import { Icon } from "@iconify-icon/solid";
import { destructure } from "@solid-primitives/destructure";
import { useQuery } from "@tanstack/solid-query";
import { createSignal, Show } from "solid-js";
import { getChatHealth } from "../api";
import { globalState, metaState } from "../state";
import { toggleDrawer } from "../state/global";

export default () => {
  const { currentChatId, currentChatTitle, currentChatCanConfigure, currentChatAccessRole } = destructure(globalState);
  const { title } = destructure(metaState);
  const [avatarVersion] = createSignal(Date.now());
  const healthQuery = useQuery(() => ({
    queryKey: ["title-health", currentChatId()],
    queryFn: () => getChatHealth(currentChatId()!),
    enabled: () => currentChatId() != null,
    refetchInterval: 30_000,
  }));
  const health = () => healthQuery.data?.success ? healthQuery.data.payload : undefined;
  const healthLabel = () => {
    if (!currentChatId()) return "未选择群组";
    if (healthQuery.isLoading) return "巡检中";
    if (!health()) return "状态不可用";
    return health()!.status === "healthy" ? "运行正常" : "需要处理";
  };
  const healthClass = () => health()?.status === "healthy"
    ? "border-tea-500/15 bg-tea-50 text-tea-600"
    : healthQuery.isLoading ? "border-sky-300/25 bg-sky-50 text-sky-700" : "border-amber-300/35 bg-amber-50 text-amber-700";

  return (
    <header class="fixed top-0 z-30 flex h-header w-full items-center border-b border-emerald-950/8 bg-[#f8fbf8]/90 pr-edge shadow-[0_8px_24px_rgba(24,35,31,0.04)] backdrop-blur-xl lg:pl-[19rem]">
      <div class="flex h-full items-center gap-3 px-edge lg:px-6">
        <button
          type="button"
          aria-label="打开导航"
          onClick={toggleDrawer}
          class="flex h-10 w-10 items-center justify-center rounded-2xl border border-emerald-950/10 bg-white text-emerald-950/70 shadow-sm transition hover:-translate-y-0.5 hover:border-tea-500/35 hover:text-tea-600 lg:hidden"
        >
          <Icon icon="solar:hamburger-menu-outline" class="text-[1.45rem]" />
        </button>
        <div class="flex items-center gap-2 lg:hidden">
          <img src={`/console/v2/bot/photo?v=${avatarVersion()}`} alt="WuFengBot 头像" class="h-9 w-9 rounded-xl border-2 border-white object-cover shadow-sm" />
          <div class="leading-tight">
            <p class="text-sm font-bold tracking-tight text-ink">WuFengBot</p>
            <p class="text-[0.65rem] font-medium text-emerald-950/45">群组控制中心</p>
          </div>
        </div>
      </div>

      <div class="min-w-0 flex-1 px-2 lg:px-6">
        <p class="truncate text-[0.68rem] font-semibold uppercase tracking-[0.16em] text-emerald-950/40">{title() || "WUFENG CONSOLE"}</p>
        <div class="mt-0.5 flex items-center gap-2">
          <Show
            when={currentChatId()}
            fallback={
              <div class="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-tea-100 text-tea-600">
                <Icon icon="solar:users-group-rounded-bold-duotone" class="text-[1.1rem]" />
              </div>
            }
          >
            <img
              src={`/console/v2/${currentChatId()}/photo?v=${avatarVersion()}`}
              alt="当前群组头像"
              class="h-7 w-7 shrink-0 rounded-lg border border-white object-cover shadow-sm"
            />
          </Show>
          <h1 class="truncate text-base font-bold text-ink lg:text-lg">{currentChatTitle() || "选择一个管理群组"}</h1>
          <Show when={currentChatTitle()}>
            <span class="hidden rounded-full bg-tea-100 px-2 py-0.5 text-[0.66rem] font-bold text-tea-600 sm:inline-flex">{currentChatAccessRole() === "owner" ? "群主模式" : currentChatCanConfigure() ? "管理员配置" : "管理员只读"}</span>
          </Show>
        </div>
      </div>

      <div class={`flex shrink-0 items-center gap-2 rounded-full border px-3 py-2 text-xs font-bold lg:mr-2 ${healthClass()}`}>
        <span class={health()?.status === "healthy" ? "relative flex h-2 w-2" : "flex h-2 w-2 rounded-full bg-current/70"}>
          <Show when={health()?.status === "healthy"}><span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-tea-500 opacity-40" /><span class="relative inline-flex h-2 w-2 rounded-full bg-tea-500" /></Show>
        </span>
        <span class="hidden sm:inline">{healthLabel()}</span>
        <span class="sm:hidden">{health()?.status === "healthy" ? "正常" : "状态"}</span>
      </div>
    </header>
  );
};
