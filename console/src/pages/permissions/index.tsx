import { Icon } from "@iconify-icon/solid";
import { destructure } from "@solid-primitives/destructure";
import { useQuery } from "@tanstack/solid-query";
import classNames from "classnames";
import { createSignal, For, onMount, Show } from "solid-js";
import { getPermissions, isApprovalPending, updatePermission } from "../../api";
import { PageBase } from "../../layouts";
import { globalState } from "../../state";
import { setCurrentPage } from "../../state/global";
import { setTitle } from "../../state/meta";
import { toaster } from "../../utils";

export default () => {
  const { currentChatId, currentChatTitle, currentChatAccessRole } = destructure(globalState);
  const isOwner = () => currentChatAccessRole() === "owner";
  const query = useQuery(() => ({
    queryKey: ["permissions", currentChatId()],
    queryFn: () => getPermissions(currentChatId()!),
    enabled: () => currentChatId() != null && isOwner(),
  }));

  onMount(() => {
    setCurrentPage("permissions");
    setTitle("权限管理");
  });

  return (
    <PageBase>
      <div class="mx-auto max-w-5xl space-y-5">
        <section class="overflow-hidden rounded-[2rem] bg-[#173d31] p-5 text-white shadow-[0_20px_55px_rgba(23,61,49,0.16)] sm:p-7">
          <div class="flex flex-col gap-5 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <div class="inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-3 py-1.5 text-[0.68rem] font-bold uppercase tracking-[0.16em] text-white/75">
                <Icon icon="solar:key-minimalistic-square-3-bold-duotone" class="text-base" /> ACCESS CONTROL
              </div>
              <h1 class="mt-4 text-2xl font-black sm:text-3xl">权限管理</h1>
              <p class="mt-2 max-w-2xl text-sm leading-6 text-white/65">由群主决定每位管理员能否进入后台、执行机器人功能或修改群配置。权限按群独立保存。</p>
            </div>
            <div class="rounded-2xl border border-white/10 bg-white/10 px-4 py-3 sm:min-w-56">
              <p class="text-[0.68rem] font-semibold text-white/50">当前群组</p>
              <p class="mt-1 truncate text-sm font-bold">{currentChatTitle() || "尚未选择群组"}</p>
              <p class="mt-1 text-xs font-semibold text-[#b8d8c1]">{isOwner() ? "群主可编辑" : "仅群主可设置"}</p>
            </div>
          </div>
        </section>

        <Show when={currentChatId() && !isOwner()}>
          <section class="rounded-3xl border border-amber-300/45 bg-amber-50 p-5 text-amber-950">
            <div class="flex items-start gap-3">
              <Icon icon="solar:lock-keyhole-minimalistic-bold-duotone" class="mt-0.5 shrink-0 text-2xl text-amber-600" />
              <div>
                <h2 class="font-bold">只有本群群主可以调整权限</h2>
                <p class="mt-1 text-sm leading-6 text-amber-900/70">管理员不能给自己或其他人增加权限。请由群主打开本页面进行设置。</p>
              </div>
            </div>
          </section>
        </Show>

        <Show when={isOwner()}>
          <section class="panel-card p-4 sm:p-5">
            <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <h2 class="panel-section-title"><Icon icon="solar:users-group-two-rounded-bold-duotone" class="text-xl text-tea-600" />群管理员授权</h2>
                <p class="panel-muted">关闭“后台访问”会同时关闭该管理员的执行和配置权限。</p>
              </div>
              <div class="rounded-full bg-tea-50 px-3 py-1.5 text-xs font-bold text-tea-600">Telegram 管理员自动同步</div>
            </div>

            <div class="mt-5 grid gap-3">
              <Show when={!query.isLoading} fallback={<LoadingState />}>
                <For each={query.data?.success ? query.data.payload : []}>
                  {(permission) => <PermissionCard chatId={currentChatId()!} data={permission} />}
                </For>
              </Show>
            </div>
          </section>

          <section class="rounded-3xl border border-emerald-950/8 bg-white p-5 text-sm leading-6 text-emerald-950/65 shadow-sm">
            <div class="flex items-start gap-3">
              <Icon icon="solar:info-circle-bold-duotone" class="mt-0.5 shrink-0 text-xl text-tea-600" />
              <div>
                <p class="font-bold text-ink">权限说明</p>
                <p>这里控制 WuFengBot 的后台和机器人功能，不会改变 Telegram 群组原生管理员身份。群主权限始终完整且不能关闭；管理员被移出 Telegram 管理员列表后，会自动从这里移除。</p>
              </div>
            </div>
          </section>
        </Show>
      </div>
    </PageBase>
  );
};

const PermissionCard = (props: { chatId: number; data: ServerData.PermissionAccess }) => {
  const [readable, setReadable] = createSignal(props.data.readable);
  const [writable, setWritable] = createSignal(props.data.writable);
  const [configurable, setConfigurable] = createSignal(props.data.configurable);
  const [baseline, setBaseline] = createSignal({
    readable: props.data.readable,
    writable: props.data.writable,
    configurable: props.data.configurable,
  });
  const [saving, setSaving] = createSignal(false);
  const isOwner = () => props.data.tgIsOwner;
  const changed = () => readable() !== baseline().readable || writable() !== baseline().writable || configurable() !== baseline().configurable;

  const changeReadable = (value: boolean) => {
    setReadable(value);
    if (!value) {
      setWritable(false);
      setConfigurable(false);
    }
  };

  const changeWritable = (value: boolean) => {
    setWritable(value);
    if (value) setReadable(true);
  };

  const changeConfigurable = (value: boolean) => {
    setConfigurable(value);
    if (value) setReadable(true);
  };

  const save = async () => {
    if (isOwner() || !changed() || saving()) return;
    setSaving(true);
    try {
      const response = await updatePermission(props.chatId, props.data.userId, {
        readable: readable(),
        writable: writable(),
        configurable: configurable(),
      });
      if (isApprovalPending(response)) return;
      if (response.success) {
        setBaseline({ readable: readable(), writable: writable(), configurable: configurable() });
        toaster.success({ title: "权限已保存", description: `${props.data.fullName} 的权限已立即生效` });
      } else {
        toaster.error({ title: "权限未保存", description: response.message, duration: 5_000 });
      }
    } catch (error) {
      toaster.error({ title: "保存失败", description: error instanceof Error ? error.message : "权限未修改，请稍后重试", duration: 5_000 });
    } finally {
      setSaving(false);
    }
  };

  return (
    <article class="rounded-3xl border border-emerald-950/8 bg-[#fbfcfa] p-4 sm:p-5">
      <div class="flex flex-col gap-4 xl:flex-row xl:items-center">
        <div class="flex min-w-0 items-center gap-3 xl:w-64">
          <div class={classNames(["flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl text-lg font-black", isOwner() ? "bg-[#173d31] text-white" : "bg-tea-100 text-tea-700"])}>
            {initials(props.data.fullName)}
          </div>
          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <p class="truncate font-bold text-ink">{props.data.fullName}</p>
              <span class={classNames(["shrink-0 rounded-full px-2 py-0.5 text-[0.62rem] font-bold", isOwner() ? "bg-[#173d31] text-white" : "bg-tea-100 text-tea-700"])}>{isOwner() ? "群主" : "管理员"}</span>
            </div>
            <p class="mt-1 truncate text-xs text-emerald-950/45">{props.data.username ? `@${props.data.username}` : `ID ${props.data.userId}`}</p>
          </div>
        </div>

        <div class="grid flex-1 gap-2 sm:grid-cols-3">
          <AccessSwitch label="后台访问" description="查看控制台与群配置" checked={readable()} disabled={isOwner()} onChange={changeReadable} />
          <AccessSwitch label="执行功能" description="抽奖、开奖与成员处理" checked={writable()} disabled={isOwner()} onChange={changeWritable} />
          <AccessSwitch label="修改配置" description="保存机器人全部设置" checked={configurable()} disabled={isOwner()} onChange={changeConfigurable} />
        </div>

        <div class="flex items-center justify-end gap-2 xl:w-28">
          <Show when={props.data.customized && !isOwner()}><span class="rounded-full bg-violet-100 px-2 py-1 text-[0.62rem] font-bold text-violet-700">已自定义</span></Show>
          <Show when={!isOwner()}>
            <button type="button" disabled={!changed() || saving()} onClick={save} class="rounded-xl bg-tea-600 px-4 py-2 text-sm font-bold text-white shadow-sm transition hover:bg-tea-700 disabled:cursor-not-allowed disabled:opacity-40">
              {saving() ? "保存中" : "保存"}
            </button>
          </Show>
        </div>
      </div>
    </article>
  );
};

const AccessSwitch = (props: { label: string; description: string; checked: boolean; disabled?: boolean; onChange: (value: boolean) => void }) => (
  <button type="button" disabled={props.disabled} aria-pressed={props.checked} onClick={() => props.onChange(!props.checked)} class={classNames(["flex items-center justify-between gap-3 rounded-2xl border px-3 py-3 text-left transition", props.checked ? "border-tea-500/25 bg-tea-50" : "border-emerald-950/8 bg-white", props.disabled ? "cursor-not-allowed opacity-75" : "hover:border-tea-500/35"])}>
    <span class="min-w-0"><span class="block text-sm font-bold text-ink">{props.label}</span><span class="mt-0.5 block truncate text-[0.68rem] text-emerald-950/45">{props.description}</span></span>
    <span class={classNames(["relative h-6 w-11 shrink-0 rounded-full transition", props.checked ? "bg-tea-600" : "bg-emerald-950/15"])}><span class={classNames(["absolute top-1 h-4 w-4 rounded-full bg-white shadow-sm transition", props.checked ? "left-6" : "left-1"])} /></span>
  </button>
);

const LoadingState = () => <div class="rounded-2xl bg-emerald-950/4 px-4 py-8 text-center text-sm font-semibold text-emerald-950/45">正在读取管理员权限…</div>;

function initials(name: string) {
  const value = name.trim();
  return value ? Array.from(value).slice(0, 2).join("").toUpperCase() : "管";
}
