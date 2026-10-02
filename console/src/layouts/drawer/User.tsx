import { Icon } from "@iconify-icon/solid";
import { createSignal, Show } from "solid-js";
import Loading from "../../components/Loading";

export default (props: { data?: ServerData.User }) => {
  const [avatarVersion] = createSignal(Date.now());

  return (
    <div class="px-4 pb-4">
      <Show when={props.data} fallback={<MyLoading />}>
        <div class="relative overflow-hidden rounded-3xl border border-tea-500/15 bg-gradient-to-br from-[#eaf5ee] via-white to-[#f7fbf8] p-4 shadow-sm">
          <div class="absolute -right-6 -top-8 h-24 w-24 rounded-full bg-tea-100/70" />
          <div class="relative flex items-center gap-3">
            <img
              width={320}
              height={320}
              src={`/console/v2/${props.data?.id}/photo?v=${avatarVersion()}`}
              alt="Telegram账号头像"
              class="h-12 w-12 rounded-2xl border-2 border-white object-cover shadow-sm"
            />
            <div class="min-w-0 flex-1">
              <p class="text-[0.65rem] font-bold uppercase tracking-[0.14em] text-tea-600">已连接账号</p>
              <p class="mt-1 truncate text-sm font-bold text-ink">{props.data?.fullName}</p>
            </div>
            <div class="flex h-8 w-8 items-center justify-center rounded-xl bg-white text-tea-600 shadow-sm">
              <Icon icon="solar:shield-check-bold-duotone" class="text-[1.15rem]" />
            </div>
          </div>
          <div class="relative mt-4 flex items-center gap-2 rounded-2xl bg-white/75 px-3 py-2 text-xs font-semibold text-emerald-950/60">
            <span class="h-1.5 w-1.5 rounded-full bg-tea-500" />
            可管理多个 Telegram 群组
          </div>
        </div>
      </Show>
    </div>
  );
};

const MyLoading = () => {
  return (
    <div class="flex items-center justify-center h-full">
      <Loading size="xl" color="lightcoral" />
    </div>
  );
};
