import { createSignal, For, Show } from "solid-js";
import { ActionButton } from "../../components";
import { isApprovalPending } from "../../api";
import { toaster } from "../../utils";
import { inputClass, SettingCard, Toggle } from "./controls";

type Props = {
  items: ServerData.KeywordReply[];
  onCreate: (input: InputData.KeywordReply) => Promise<ApiResponse<ServerData.KeywordReply>>;
  onUpdate: (id: number, input: InputData.KeywordReply) => Promise<ApiResponse<ServerData.KeywordReply>>;
  onDelete: (id: number) => Promise<ApiResponse<ServerData.KeywordReply>>;
};

const emptyButton = (): InputData.KeywordReplyButton => ({ text: "", url: "" });

export const KeywordReplySettings = (props: Props) => {
  const [editingId, setEditingId] = createSignal<number | null>(null);
  const [keywordsText, setKeywordsText] = createSignal("");
  const [responseText, setResponseText] = createSignal("");
  const [matchMode, setMatchMode] = createSignal<InputData.KeywordReply["match_mode"]>("contains");
  const [caseSensitive, setCaseSensitive] = createSignal(false);
  const [enabled, setEnabled] = createSignal(true);
  const [buttons, setButtons] = createSignal<InputData.KeywordReplyButton[]>([]);

  const reset = () => {
    setEditingId(null);
    setKeywordsText("");
    setResponseText("");
    setMatchMode("contains");
    setCaseSensitive(false);
    setEnabled(true);
    setButtons([]);
  };

  const edit = (item: ServerData.KeywordReply) => {
    setEditingId(item.id);
    setKeywordsText((item.keywords?.length ? item.keywords : [item.keyword]).join("\n"));
    setResponseText(item.responseText);
    setMatchMode(item.matchMode);
    setCaseSensitive(item.caseSensitive);
    setEnabled(item.enabled);
    setButtons(item.buttons.map((button) => ({ ...button })));
  };

  const save = async () => {
    const keywords = [...new Set(keywordsText().split(/\r?\n/).map((value) => value.trim()).filter(Boolean))];

    if (keywords.length === 0 || !responseText().trim()) {
      toaster.error({ title: "内容不完整", description: "至少填写一个关键词，并填写自动回复内容。" });
      return;
    }

    if (keywords.length > 50 || keywords.some((value) => value.length > 200)) {
      toaster.error({ title: "关键词过多或过长", description: "每条规则最多 50 个关键词，每个关键词最多 200 个字符。" });
      return;
    }

    if (buttons().some((button) => !button.text.trim() || !button.url.trim())) {
      toaster.error({ title: "按钮不完整", description: "每个按钮都必须填写按钮文字和跳转链接。" });
      return;
    }

    const input: InputData.KeywordReply = {
      keywords,
      response_text: responseText().trim(),
      match_mode: matchMode(),
      case_sensitive: caseSensitive(),
      enabled: enabled(),
      buttons: buttons().map((button) => ({ text: button.text.trim(), url: button.url.trim() })),
    };
    const id = editingId();
    const response = id === null ? await props.onCreate(input) : await props.onUpdate(id, input);

    if (isApprovalPending(response) || response.success) reset();
    else toaster.error({ title: "保存失败", description: response.message });
  };

  const remove = async (id: number) => {
    const response = await props.onDelete(id);
    if (!isApprovalPending(response) && !response.success) {
      toaster.error({ title: "删除失败", description: response.message });
    }
  };

  const updateButton = (index: number, field: keyof InputData.KeywordReplyButton, value: string) => {
    setButtons((current) => current.map((button, position) => position === index ? { ...button, [field]: value } : button));
  };

  return <div class="grid gap-5 xl:grid-cols-2 xl:col-span-2">
    <SettingCard icon="solar:chat-square-arrow-bold-duotone" title={editingId() === null ? "新增关键词回复" : "编辑关键词回复"} description="成员消息命中关键词后，自动回复文字并显示可选跳转按钮。">
      <div class="grid gap-3 sm:grid-cols-[1fr_9rem]">
        <textarea class={inputClass} rows="3" value={keywordsText()} onInput={(event) => setKeywordsText(event.currentTarget.value)} placeholder={"多个关键词请每行填写一个，例如：\n官网\n客服\n价格"} />
        <select class={inputClass} value={matchMode()} onChange={(event) => setMatchMode(event.currentTarget.value as InputData.KeywordReply["match_mode"])}>
          <option value="contains">包含关键词</option><option value="exact">完全一致</option><option value="prefix">以关键词开头</option>
        </select>
      </div>
      <p class="text-xs leading-5 text-emerald-950/50">同一规则最多 50 个关键词，每行一个，共用下面的回复内容和按钮。</p>
      <textarea class={inputClass} rows="5" maxLength={4096} value={responseText()} onInput={(event) => setResponseText(event.currentTarget.value)} placeholder="机器人要自动回复的内容" />
      <p class="text-xs leading-5 text-emerald-950/50">可使用：&#123;user&#125; 姓名、&#123;username&#125; 用户名、&#123;id&#125; 用户 ID。</p>
      <div class="grid gap-2 sm:grid-cols-2"><Toggle label="启用这条规则" checked={enabled()} onChange={setEnabled} /><Toggle label="区分大小写" checked={caseSensitive()} onChange={setCaseSensitive} /></div>
      <div class="space-y-2 rounded-xl border border-tea-500/15 bg-tea-50/60 p-3">
        <div class="flex items-center justify-between gap-3"><strong class="text-sm text-ink">跳转按钮（最多 8 个）</strong><ActionButton variant="info" outline size="sm" onClick={() => buttons().length < 8 && setButtons((current) => [...current, emptyButton()])}>添加按钮</ActionButton></div>
        <For each={buttons()}>{(button, index) => <div class="grid gap-2 sm:grid-cols-[9rem_1fr_auto]"><input class={inputClass} value={button.text} maxLength={64} onInput={(event) => updateButton(index(), "text", event.currentTarget.value)} placeholder="按钮文字" /><input class={inputClass} value={button.url} maxLength={2048} onInput={(event) => updateButton(index(), "url", event.currentTarget.value)} placeholder="https://... 或 tg://..." /><ActionButton variant="danger" size="sm" onClick={() => setButtons((current) => current.filter((_, position) => position !== index()))}>移除</ActionButton></div>}</For>
        <Show when={buttons().length === 0}><p class="text-xs text-emerald-950/45">不添加按钮时只发送文字回复。</p></Show>
      </div>
      <div class="flex flex-wrap gap-2"><ActionButton variant="info" size="lg" onClick={save}>{editingId() === null ? "提交新增" : "保存修改"}</ActionButton><Show when={editingId() !== null}><ActionButton outline size="lg" onClick={reset}>取消编辑</ActionButton></Show></div>
    </SettingCard>
    <SettingCard icon="solar:list-check-bold-duotone" title="现有自动回复" description="点击编辑可调整关键词组、正文、匹配方式、启停状态和跳转按钮。">
      <Show when={props.items.length > 0} fallback={<p class="panel-muted rounded-xl bg-tea-50 p-4 text-center">暂未设置关键词自动回复</p>}>
        <div class="max-h-[38rem] space-y-3 overflow-y-auto pr-1"><For each={props.items}>{(item) => <div class="rounded-xl border border-emerald-950/8 bg-white p-3"><div class="flex items-start justify-between gap-3"><div class="min-w-0"><div class="flex flex-wrap items-center gap-2"><For each={item.keywords?.length ? item.keywords : [item.keyword]}>{(keyword) => <span class="break-all rounded-lg bg-tea-50 px-2 py-1 text-sm font-bold text-ink">{keyword}</span>}</For><span class={item.enabled ? "rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700" : "rounded-full bg-slate-100 px-2 py-0.5 text-xs text-slate-500"}>{item.enabled ? "已启用" : "已停用"}</span></div><p class="mt-1 line-clamp-3 whitespace-pre-wrap text-sm text-emerald-950/65">{item.responseText}</p><p class="mt-2 text-xs text-emerald-950/45">{item.keywords?.length || 1} 个关键词 · {modeLabel(item.matchMode)} · {item.caseSensitive ? "区分大小写" : "不区分大小写"} · {item.buttons.length} 个按钮</p></div><div class="flex shrink-0 gap-2"><ActionButton variant="info" outline size="sm" onClick={() => edit(item)}>编辑</ActionButton><ActionButton variant="danger" size="sm" onClick={() => remove(item.id)}>删除</ActionButton></div></div></div>}</For></div>
      </Show>
    </SettingCard>
  </div>;
};

const modeLabel = (mode: string) => ({ contains: "包含匹配", exact: "完全匹配", prefix: "前缀匹配" }[mode] || mode);
