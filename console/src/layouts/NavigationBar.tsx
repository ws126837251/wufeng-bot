import { Icon } from "@iconify-icon/solid";
import { destructure } from "@solid-primitives/destructure";
import { useNavigate } from "@solidjs/router";
import classNames from "classnames";
import { globalState } from "../state";
import { toggleDrawer } from "../state/global";

const primaryItems: Array<{ page: Page; icon: string; text: string }> = [
  { page: "stats", icon: "solar:widget-5-bold-duotone", text: "工作台" },
  { page: "security", icon: "solar:shield-check-bold-duotone", text: "安全" },
  { page: "messages", icon: "solar:chat-round-dots-bold-duotone", text: "消息" },
  { page: "members", icon: "solar:users-group-rounded-bold-duotone", text: "成员" },
  { page: "lottery", icon: "solar:gift-bold-duotone", text: "抽奖" },
];

export default () => (
  <nav class="fixed bottom-0 left-0 right-0 z-50 flex h-navigation items-center border-t border-emerald-950/8 bg-white/90 backdrop-blur-md lg:hidden">
    {primaryItems.map((item) => <PageLink {...item} />)}
    <button type="button" onClick={toggleDrawer} class="flex h-full flex-1 flex-col items-center justify-between px-1 py-[0.45rem] text-emerald-950/55">
      <Icon icon="solar:hamburger-menu-bold-duotone" class="h-6 text-[1.5rem]" />
      <span class="text-[0.65rem] font-medium">更多</span>
    </button>
  </nav>
);

const PageLink = (props: { page: Page; icon: string; text: string }) => {
  const navigate = useNavigate();
  const { currentPage } = destructure(globalState);

  return (
    <button
      type="button"
      onClick={() => navigate(`/${props.page}`)}
      class={classNames([
        "flex h-full flex-1 flex-col items-center justify-between px-1 py-[0.45rem] text-emerald-950/55",
        currentPage() === props.page ? "bg-tea-50 text-tea-600" : "",
      ])}
    >
      <Icon icon={props.icon} class="h-6 text-[1.5rem]" />
      <span class="text-[0.65rem] font-medium">{props.text}</span>
    </button>
  );
};
