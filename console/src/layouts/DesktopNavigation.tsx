import { Icon } from "@iconify-icon/solid";
import { destructure } from "@solid-primitives/destructure";
import { useLocation, useNavigate } from "@solidjs/router";
import { useQuery } from "@tanstack/solid-query";
import classNames from "classnames";
import { createSignal, For, Show } from "solid-js";
import { getChats } from "../api";
import { globalState } from "../state";
import { setCurrentChat } from "../state/global";

const items: Array<{ page: Page; label: string; description: string; icon: string }> = [
  { page: "stats", label: "工作台", description: "群组状态与巡检", icon: "solar:widget-5-bold-duotone" },
  { page: "security", label: "安全管理", description: "入群验证与防护", icon: "solar:shield-check-bold-duotone" },
  { page: "messages", label: "消息管理", description: "文案与自动化", icon: "solar:chat-round-dots-bold-duotone" },
  { page: "members", label: "成员管理", description: "搜索、拉黑与解除", icon: "solar:users-group-rounded-bold-duotone" },
  { page: "lottery", label: "抽奖中心", description: "活动、名单与开奖", icon: "solar:gift-bold-duotone" },
  { page: "logs", label: "记录", description: "验证与操作记录", icon: "solar:history-bold-duotone" },
  { page: "permissions", label: "权限管理", description: "管理员与授权", icon: "solar:key-minimalistic-square-3-bold-duotone" },
  { page: "customize", label: "自定义验证", description: "题目与答案", icon: "solar:pen-new-square-bold-duotone" },
];

export default () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { currentPage, currentChatId, currentChatTitle } = destructure(globalState);
  const [pickerOpen, setPickerOpen] = createSignal(false);
  const chatsQuery = useQuery(() => ({ queryKey: ["chats"], queryFn: getChats }));
  const chats = () => chatsQuery.data?.success ? chatsQuery.data.payload : [];
  const botAvatarUrl = `/console/v2/bot/photo?v=${Date.now()}`;

  const selectChat = (chat: ServerData.Chat) => {
    const params = new URLSearchParams(location.search);
    params.set("chat_id", String(chat.id));
    setCurrentChat(chat);
    setPickerOpen(false);
    navigate(`${location.pathname}?${params.toString()}`);
  };

  return (
    <aside class="fixed bottom-0 left-0 top-0 z-40 hidden w-[17rem] flex-col border-r border-emerald-950/8 bg-[#f8fbf8] px-4 py-6 lg:flex">
      <div class="rounded-3xl border border-tea-500/15 bg-white p-3 shadow-sm">
        <div class="flex items-center gap-3">
          <img src={botAvatarUrl} alt="WuFengBot 头像" class="h-11 w-11 rounded-2xl border-2 border-white object-cover shadow-sm" />
          <div class="min-w-0">
            <p class="truncate text-lg font-bold tracking-tight text-ink">WuFengBot</p>
            <p class="text-xs font-medium text-emerald-950/45">群组控制中心</p>
          </div>
        </div>
        <div class="relative mt-3">
          <button
            type="button"
            onClick={() => setPickerOpen((value) => !value)}
            class="flex w-full items-center gap-2 rounded-2xl bg-tea-50 px-3 py-2 text-left text-xs font-semibold text-tea-700 transition hover:bg-tea-100"
          >
            <Icon icon="solar:users-group-rounded-bold-duotone" class="text-base" />
            <span class="min-w-0 flex-1 truncate">{currentChatTitle() || "选择管理群组"}</span>
            <Icon icon={pickerOpen() ? "solar:alt-arrow-up-linear" : "solar:alt-arrow-down-linear"} class="text-sm" />
          </button>
          <Show when={pickerOpen()}>
            <div class="absolute left-0 right-0 top-[calc(100%+0.5rem)] z-50 max-h-72 overflow-y-auto rounded-2xl border border-emerald-950/10 bg-white p-1.5 shadow-xl">
              <Show when={!chatsQuery.isLoading} fallback={<p class="px-3 py-4 text-xs text-emerald-950/45">正在读取群组…</p>}>
                <For each={chats()} fallback={<p class="px-3 py-4 text-xs text-emerald-950/45">没有可管理的群组</p>}>
                  {(chat) => (
                    <button
                      type="button"
                      onClick={() => selectChat(chat)}
                      class={classNames([
                        "flex w-full items-center gap-2 rounded-xl px-3 py-2.5 text-left text-sm transition",
                        currentChatId() === chat.id ? "bg-tea-50 font-bold text-tea-700" : "text-emerald-950/70 hover:bg-emerald-950/4",
                      ])}
                    >
                      <img src={`/console/v2/${chat.id}/photo`} alt="" class="h-7 w-7 rounded-lg bg-emerald-950/5 object-cover" />
                      <span class="min-w-0 flex-1 truncate">{chat.title}</span>
                      <Show when={currentChatId() === chat.id}><Icon icon="solar:check-circle-bold" class="text-tea-600" /></Show>
                    </button>
                  )}
                </For>
              </Show>
            </div>
          </Show>
        </div>
      </div>
      <div class="mb-3 mt-6 px-2 text-[0.68rem] font-bold uppercase tracking-[0.16em] text-emerald-950/40">管理空间</div>
      <nav class="space-y-1.5">
        <For each={items}>
          {(item) => (
            <button
              type="button"
              onClick={() => navigate(`/${item.page}`)}
              class={classNames([
                "group flex w-full items-center gap-3 rounded-2xl border px-3 py-2.5 text-left transition",
                currentPage() === item.page ? "border-tea-500/15 bg-tea-50 text-tea-600 shadow-sm" : "border-transparent text-emerald-950/60 hover:border-emerald-950/5 hover:bg-white",
              ])}
            >
              <span class={classNames(["flex h-9 w-9 shrink-0 items-center justify-center rounded-xl transition", currentPage() === item.page ? "bg-white text-tea-600" : "bg-emerald-950/5 text-emerald-950/50 group-hover:bg-tea-50 group-hover:text-tea-600"])}>
                <Icon icon={item.icon} class="text-[1.3rem]" />
              </span>
              <span class="min-w-0"><span class="block text-sm font-semibold">{item.label}</span><span class="mt-0.5 block text-[0.68rem] opacity-60">{item.description}</span></span>
            </button>
          )}
        </For>
      </nav>
      <div class="mt-auto overflow-hidden rounded-3xl bg-[#173d31] p-4 text-sm text-white shadow-[0_12px_28px_rgba(23,61,49,0.16)]">
        <div class="flex items-center gap-2 font-bold text-[#b8d8c1]"><Icon icon="solar:shield-check-bold-duotone" class="text-lg" />操作提示</div>
        <p class="mt-2 text-xs leading-5 text-white/60">当前群组会固定显示在顶部；任何保存、审批和执行结果都只作用于该群。</p>
      </div>
    </aside>
  );
};
