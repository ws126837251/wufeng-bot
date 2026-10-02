import { Icon } from "@iconify-icon/solid";
import classNames from "classnames";
import { createSignal, For, Show } from "solid-js";

const Switcher = (props: {
  current?: ServerData.Chat;
  isLoading?: boolean;
  canSwitch?: boolean;
  chats: ServerData.Chat[];
  onSelect?: (chat: ServerData.Chat) => void;
  onCopy?: (source: ServerData.Chat) => Promise<boolean>;
}) => {
  const [pickerOpen, setPickerOpen] = createSignal(false);
  const [copyOpen, setCopyOpen] = createSignal(false);
  const [copySource, setCopySource] = createSignal<ServerData.Chat>();
  const [copying, setCopying] = createSignal(false);

  const confirmCopy = async () => {
    const source = copySource();
    if (!source || copying()) return;

    setCopying(true);
    try {
      if (await props.onCopy?.(source)) {
        setCopyOpen(false);
        setPickerOpen(false);
        setCopySource();
      }
    } finally {
      setCopying(false);
    }
  };
  return (
    <div class="px-4 pb-4">
      <div class="flex items-center gap-3 rounded-2xl border border-emerald-950/8 bg-white p-3 shadow-sm">
        <Show
          when={!props.isLoading}
          fallback={<p class="min-w-0 flex-1 text-sm font-semibold text-emerald-950/45">正在读取管理群组…</p>}
        >
          <Show
            when={props.current}
            fallback={<p class="min-w-0 flex-1 text-sm font-semibold text-emerald-950/45">暂未发现可管理群组</p>}
          >
            {(chat) => (
              <>
                <img src={`/console/v2/${chat().id}/photo`} width={128} height={128} class="h-10 w-10 shrink-0 rounded-xl border-2 border-white object-cover shadow-sm" />
                <div class="min-w-0 flex-1">
                  <p class="text-[0.63rem] font-bold tracking-[0.12em] text-emerald-950/40">当前管理群组</p>
                  <p class="mt-0.5 truncate text-sm font-bold text-ink">{chat().title}</p>
                </div>
              </>
            )}
          </Show>
        </Show>
        <button
          type="button"
          onClick={() => setPickerOpen(true)}
          disabled={!props.canSwitch || props.isLoading}
          class={classNames([
            "shrink-0 rounded-lg px-2 py-1.5 text-xs font-bold transition",
            props.canSwitch && !props.isLoading
              ? "text-tea-700 hover:bg-tea-50 hover:text-tea-800"
              : "cursor-not-allowed text-emerald-950/25",
          ])}
        >
          <span class="inline-flex items-center gap-1"><Icon icon="solar:refresh-circle-linear" class="text-sm" />切换群组</span>
        </button>
      </div>
      <Show when={pickerOpen()}>
        <div class="fixed inset-0 z-[70] flex items-end bg-black/35 p-3" onClick={() => setPickerOpen(false)}>
          <section class="w-full rounded-3xl bg-white p-4 shadow-2xl" onClick={(event) => event.stopPropagation()}>
            <Show
              when={copyOpen()}
              fallback={
                <>
                  <div class="mb-3 flex items-center justify-between"><div><p class="text-base font-bold text-ink">选择管理群组</p><p class="mt-0.5 text-xs text-emerald-950/45">选择后才会切换，设置仅作用于该群。</p></div><button type="button" onClick={() => setPickerOpen(false)} class="text-sm font-bold text-emerald-950/45">取消</button></div>
                  <div class="space-y-2">
                    <For each={props.chats}>
                      {(chat) => <button type="button" onClick={() => { props.onSelect?.(chat); setPickerOpen(false); }} class="flex w-full items-center gap-3 rounded-2xl border border-emerald-950/8 p-3 text-left transition hover:bg-tea-50"><img src={`/console/v2/${chat.id}/photo`} class="h-10 w-10 rounded-xl object-cover" /><span class="min-w-0 flex-1 truncate text-sm font-bold text-ink">{chat.title}</span><Show when={chat.id === props.current?.id}><Icon icon="solar:check-circle-bold" class="text-tea-600" /></Show></button>}
                    </For>
                  </div>
                  <Show when={props.current && props.chats.length > 1}>
                    <button type="button" onClick={() => setCopyOpen(true)} class="mt-3 flex w-full items-center justify-center gap-1.5 rounded-2xl bg-tea-50 px-3 py-3 text-sm font-bold text-tea-700 transition hover:bg-tea-100"><Icon icon="solar:copy-linear" />复制另一个群的管理设置</button>
                  </Show>
                </>
              }
            >
              <div class="mb-3 flex items-center justify-between"><div><p class="text-base font-bold text-ink">复制管理设置</p><p class="mt-0.5 text-xs text-emerald-950/45">将覆盖当前群的验证与自动化配置。</p></div><button type="button" onClick={() => { setCopyOpen(false); setCopySource(); }} class="text-sm font-bold text-emerald-950/45">返回</button></div>
              <p class="mb-2 text-xs font-semibold text-emerald-950/55">当前群：{props.current?.title}</p>
              <div class="space-y-2">
                <For each={props.chats.filter((chat) => chat.id !== props.current?.id)}>
                  {(chat) => <button type="button" onClick={() => setCopySource(chat)} class={classNames(["flex w-full items-center gap-3 rounded-2xl border p-3 text-left transition", copySource()?.id === chat.id ? "border-tea-500 bg-tea-50" : "border-emerald-950/8 hover:bg-tea-50"])}><img src={`/console/v2/${chat.id}/photo`} class="h-10 w-10 rounded-xl object-cover" /><span class="min-w-0 flex-1 truncate text-sm font-bold text-ink">{chat.title}</span><Show when={copySource()?.id === chat.id}><Icon icon="solar:check-circle-bold" class="text-tea-600" /></Show></button>}
                </For>
              </div>
              <Show when={copySource()}>
                <div class="mt-3 rounded-2xl bg-amber-50 p-3 text-xs leading-5 text-amber-900">确认后会用“{copySource()?.title}”覆盖当前群的入群验证、自动删除、欢迎语、违禁词、关键词回复与自定义验证题；不会复制定时消息、抽奖、成员或记录。</div>
                <button type="button" disabled={copying()} onClick={confirmCopy} class="mt-3 w-full rounded-2xl bg-tea-600 px-3 py-3 text-sm font-bold text-white disabled:opacity-50">{copying() ? "正在复制…" : "确认复制设置"}</button>
              </Show>
            </Show>
          </section>
        </div>
      </Show>
    </div>
  );
};

export const Chat = { Switcher };
