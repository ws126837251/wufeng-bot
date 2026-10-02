import { destructure } from "@solid-primitives/destructure";
import { Icon } from "@iconify-icon/solid";
import { useQuery, useQueryClient } from "@tanstack/solid-query";
import classNames from "classnames";
import { createEffect, For } from "solid-js";
import { useNavigate } from "@solidjs/router";
import { copyManagementSettings, getChats, getMe } from "../../api";
import { globalState } from "../../state";
import { closeDrawer, setCurrentChat, setEmptyChatList, toggleDrawer } from "../../state/global";
import { Chat } from "./Chat";
import User from "./User";
import { toaster } from "../../utils/toaster";

export default () => {
  const { drawerIsOpen, currentChatId } = destructure(globalState);
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const botAvatarUrl = `/console/v2/bot/photo?v=${Date.now()}`;

  const meQuery = useQuery(() => ({
    queryKey: ["me"],
    queryFn: getMe,
  }));

  const chatsQuery = useQuery(() => ({
    queryKey: ["chats"],
    queryFn: getChats,
  }));

  const handleChatChange = (chat: ServerData.Chat) => {
    setCurrentChat(chat);
    // 切换群组后始终回到工作台，避免沿用旧页面的路由状态导致内容区空白。
    navigate(`/stats?chat_id=${chat.id}`, { replace: true });
    closeDrawer();
  };

  const handleCopySettings = async (source: ServerData.Chat) => {
    const target = chatsQuery.data?.success
      ? chatsQuery.data.payload.find((chat) => chat.id === currentChatId())
      : undefined;

    if (!target) return false;

    const result = await copyManagementSettings(target.id, source.id);
    if (!result.success) return false;

    await Promise.all([
      "scheme", "automation", "forbidden-words", "keyword-replies", "forbidden-whitelist", "customs",
    ].map((key) => queryClient.invalidateQueries({ queryKey: [key, target.id] })));

    toaster.success({
      title: "管理设置已复制",
      description: `已从“${source.title}”复制到“${target.title}”。`,
      duration: 4_000,
    });
    return true;
  };

  createEffect(() => {
    if (chatsQuery.data?.success) {
      if (chatsQuery.data.payload.length > 0) {
        setEmptyChatList(false);
        const requestedId = Number(new URLSearchParams(location.search).get("chat_id"));
        const currentChat = chatsQuery.data.payload.find((chat) => chat.id === requestedId)
          || chatsQuery.data.payload.find((chat) => chat.id === currentChatId())
          || chatsQuery.data.payload[0];
        setCurrentChat(currentChat);
      } else {
        setEmptyChatList(true);
      }
    }
  });

  return (
    <nav
      id="drawer"
      class={classNames([
        "flex flex-col overflow-hidden border-r border-emerald-950/8 bg-[#f8fbf8] lg:hidden",
        {
          "open": drawerIsOpen(),
          "close": !drawerIsOpen(),
        },
      ])}
    >
      <div class="flex items-center justify-between border-b border-emerald-950/8 px-4 py-4">
        <div class="flex items-center gap-2.5">
          <img src={botAvatarUrl} alt="WuFengBot 头像" class="h-10 w-10 rounded-2xl border-2 border-white object-cover shadow-sm" />
          <div class="leading-tight">
            <p class="text-sm font-bold tracking-tight text-ink">WuFengBot</p>
            <p class="text-[0.65rem] font-medium text-emerald-950/45">群组控制中心</p>
          </div>
        </div>
        <button type="button" aria-label="关闭导航" onClick={toggleDrawer} class="flex h-9 w-9 items-center justify-center rounded-xl border border-emerald-950/10 bg-white text-emerald-950/55 transition hover:text-tea-600">
          <Icon icon="solar:close-circle-linear" class="text-[1.35rem]" />
        </button>
      </div>
      <div class="px-4 pt-4">
        <p class="mb-3 px-1 text-[0.68rem] font-bold uppercase tracking-[0.16em] text-emerald-950/40">账号状态</p>
      </div>
      <User data={meQuery.data?.success ? meQuery.data?.payload : undefined} />
      <div class="px-4 pb-3">
        <p class="px-1 text-[0.68rem] font-bold uppercase tracking-[0.16em] text-emerald-950/40">管理群组</p>
      </div>
      <Chat.Switcher
        current={chatsQuery.data?.success ? chatsQuery.data.payload.find((chat) => chat.id === currentChatId()) : undefined}
        isLoading={chatsQuery.isLoading}
        canSwitch={(chatsQuery.data?.success ? chatsQuery.data.payload.length : 0) > 1}
        chats={chatsQuery.data?.success ? chatsQuery.data.payload : []}
        onSelect={handleChatChange}
        onCopy={handleCopySettings}
      />
      <div class="border-t border-emerald-950/8 px-4 py-3">
        <p class="mb-2 px-1 text-[0.68rem] font-bold uppercase tracking-[0.16em] text-emerald-950/40">功能导航</p>
        <div class="grid grid-cols-2 gap-2">
          <For each={[
            ["stats", "工作台"], ["security", "安全管理"], ["messages", "消息管理"], ["members", "成员管理"],
            ["lottery", "抽奖中心"], ["logs", "记录"], ["customize", "自定义验证"], ["permissions", "权限管理"],
          ] as Array<[Page, string]>}>
            {([page, label]) => <button type="button" onClick={() => { navigate(`/${page}`); closeDrawer(); }} class="rounded-xl bg-emerald-950/4 px-2 py-2 text-left text-xs font-semibold text-emerald-950/65">{label}</button>}
          </For>
        </div>
      </div>
      <div class="border-t border-emerald-950/8 px-4 py-4 text-xs leading-5 text-emerald-950/45">
        <div class="flex items-center gap-2 font-semibold text-tea-600"><Icon icon="solar:lock-keyhole-minimalistic-bold-duotone" class="text-base" />安全连接</div>
        <p class="mt-1">切换群组后，所有设置只会作用于当前群组。</p>
      </div>
    </nav>
  );
};
