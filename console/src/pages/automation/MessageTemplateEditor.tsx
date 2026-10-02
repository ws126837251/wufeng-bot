import { Icon } from "@iconify-icon/solid";
import { createMemo, createSignal, For, Show } from "solid-js";
import { inputClass, SettingCard } from "./controls";

type Props = {
  catalog: ServerData.MessageTemplateGroup[];
  values: Record<string, string>;
  onChange: (key: string, value: string) => void;
};

export const MessageTemplateEditor = (props: Props) => {
  const [activeGroup, setActiveGroup] = createSignal("verification");
  const [search, setSearch] = createSignal("");

  const groups = createMemo(() => props.catalog || []);
  const fields = createMemo(() => {
    const query = search().trim().toLowerCase();
    const group = groups().find((item) => item.id === activeGroup()) || groups()[0];
    if (!group) return [];
    if (!query) return group.fields;
    return group.fields.filter((field) =>
      `${field.label} ${field.description} ${field.key}`.toLowerCase().includes(query)
    );
  });

  const currentValue = (field: ServerData.MessageTemplateField) =>
    props.values[field.key] || field.defaultText;

  return (
    <SettingCard
      icon="solar:text-square-bold-duotone"
      title="机器人文案中心"
      description="输入框中显示的就是机器人当前实际发送内容，修改并保存后仅对当前群生效。"
    >
      <div class="rounded-2xl border border-tea-500/15 bg-gradient-to-br from-tea-50 to-white p-4">
        <div class="flex items-start gap-3">
          <span class="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-tea-100 text-tea-700">
            <Icon icon="solar:chat-round-check-bold-duotone" class="text-2xl" />
          </span>
          <div>
            <p class="font-bold text-ink">当前内容已自动载入</p>
            <p class="mt-1 text-xs leading-5 text-emerald-950/55">
              不再显示空白模板。带花括号的内容是自动变量，例如姓名、人数和开奖时间，建议保留。
            </p>
          </div>
        </div>
      </div>

      <div class="flex gap-2 overflow-x-auto pb-1">
        <For each={groups()}>
          {(group) => (
            <button
              type="button"
              onClick={() => { setActiveGroup(group.id); setSearch(""); }}
              class={activeGroup() === group.id
                ? "shrink-0 rounded-full bg-tea-600 px-4 py-2 text-sm font-bold text-white"
                : "shrink-0 rounded-full bg-tea-50 px-4 py-2 text-sm font-semibold text-emerald-950/60"}
            >
              {group.label} · {group.fields.length}
            </button>
          )}
        </For>
      </div>

      <label class="relative block">
        <Icon icon="solar:magnifer-linear" class="absolute left-3 top-3.5 text-lg text-emerald-950/35" />
        <input
          class={inputClass + " pl-10"}
          value={search()}
          onInput={(event) => setSearch(event.currentTarget.value)}
          placeholder="搜索文案名称或使用场景"
        />
      </label>

      <Show
        when={fields().length > 0}
        fallback={<p class="rounded-xl bg-tea-50 p-4 text-center text-sm text-emerald-950/50">没有找到相关文案</p>}
      >
        <div class="space-y-4">
          <For each={fields()}>
            {(field) => (
              <section class="rounded-2xl border border-emerald-950/10 bg-white p-4 shadow-sm shadow-emerald-950/5">
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <h3 class="font-bold text-ink">{field.label}</h3>
                    <p class="mt-1 text-xs leading-5 text-emerald-950/50">{field.description}</p>
                  </div>
                  <button
                    type="button"
                    class="shrink-0 rounded-lg bg-tea-50 px-2.5 py-1.5 text-xs font-semibold text-tea-700"
                    onClick={() => props.onChange(field.key, field.defaultText)}
                  >
                    恢复默认
                  </button>
                </div>
                <textarea
                  class={inputClass + " mt-3 min-h-20 font-normal leading-6 text-ink"}
                  rows={field.rows || 2}
                  value={currentValue(field)}
                  onInput={(event) => props.onChange(field.key, event.currentTarget.value)}
                />
                <div class="mt-2 flex flex-wrap items-center justify-between gap-2 text-xs text-emerald-950/45">
                  <span>保存键：{field.key}</span>
                  <span>可用变量：{field.variables || "无"}</span>
                </div>
              </section>
            )}
          </For>
        </div>
      </Show>
    </SettingCard>
  );
};
