import { destructure } from "@solid-primitives/destructure";
import { useQuery } from "@tanstack/solid-query";
import classNames from "classnames";
import { createEffect, createSignal, Match, onMount, Show, Switch } from "solid-js";
import { getChats, getScheme, isApprovalPending, updateScheme, updateTakeover } from "../../api";
import { ActionButton, OwnerOnlyNotice } from "../../components";
import { PageBase } from "../../layouts";
import { globalState } from "../../state";
import { setCurrentPage } from "../../state/global";
import { setTitle } from "../../state/meta";
import { toaster } from "../../utils";
import Checkbox from "./Checkbox";
import FieldGroup from "./FieldGroup";
import FieldRoot from "./FieldRoot";
import InputField from "./InputField";
import SelectField from "./SelectField";

type Scheme = ServerData.Scheme;

export default () => {
  const { currentChatId, currentChatCanConfigure } = destructure(globalState);
  const chatsQuery = useQuery(() => ({
    queryKey: ["chats"],
    queryFn: getChats,
  }));
  const query = useQuery(() => ({
    queryKey: ["scheme", currentChatId()],
    queryFn: () => getScheme(currentChatId()!),
    enabled: () => currentChatId() != null,
  }));

  const [id, setId] = createSignal<number | null>(null);
  const [type, setType] = createSignal<Scheme["type"]>(null);
  const [typeItems, setTypeItems] = createSignal<Scheme["typeItems"]>([]);
  const [timeout, setTimeout] = createSignal<Scheme["timeout"]>(null);
  const [killStrategy, setKillStrategy] = createSignal<Scheme["killStrategy"]>(null);
  const [fallbackKillStrategy, setFallbackKillStrategy] = createSignal<Scheme["fallbackKillStrategy"]>(
    null,
  );
  const [killStrategyItems, setKillStrategyItems] = createSignal<Scheme["killStrategyItems"]>([]);
  const [mentionText, setMentionText] = createSignal<Scheme["mentionText"]>(null);
  const [mentionTextItems, setMentionTextItems] = createSignal<Scheme["mentionTextItems"]>([]);
  const [imageChoicesCount, setImageChoicesCount] = createSignal<Scheme["imageChoicesCount"]>(null);
  const [imageChoicesCountItems, setImageChoicesCountItems] = createSignal<Scheme["imageChoicesCountItems"]>([]);
  const [cleanupMessages, setCleanupMessages] = createSignal<Scheme["cleanupMessages"]>(null);
  const [delayUnbanSecs, setDelayUnbanSecs] = createSignal<Scheme["delayUnbanSecs"]>(null);
  const [prevScheme, setPrevScheme] = createSignal<Scheme | null>(null);
  const [isChanged, setIsChanged] = createSignal(false);
  const [isSaving, setIsSaving] = createSignal(false);
  const [takenOver, setTakenOver] = createSignal(false);
  const [isTakingOver, setIsTakingOver] = createSignal(false);

  createEffect(() => {
    currentChatId();
    setId(null);
    setType(null);
    setTimeout(null);
    setKillStrategy(null);
    setFallbackKillStrategy(null);
    setMentionText(null);
    setImageChoicesCount(null);
    setCleanupMessages(null);
    setDelayUnbanSecs(null);
    setPrevScheme(null);
    setIsChanged(false);
    setTakenOver(false);
  });

  const handleTypeChange = (item: SelectItem) => setType(item.value);
  const handleKillStrategyChange = (item: SelectItem) => setKillStrategy(item.value);
  const handleFallbackKillStrategyChange = (item: SelectItem) => setFallbackKillStrategy(item.value);
  const handleMentionTextChange = (item: SelectItem) => setMentionText(item.value);
  const handleImageChoicesCountChange = (item: SelectItem) => setImageChoicesCount(item.value);

  const parseSeconds = (value: string, minimum: number) => {
    if (value.trim() === "") {
      return null;
    }

    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.max(minimum, Math.floor(parsed)) : null;
  };

  const handleCleanupMessagesChange = (kind: ServerData.MessageKind, checked: boolean) => {
    setCleanupMessages((prev) => {
      if (prev !== null) {
        if (checked) {
          return [...prev, kind];
        } else {
          return prev.filter((item) => item !== kind);
        }
      } else {
        if (checked) {
          return [kind];
        } else {
          return null;
        }
      }
    });
  };

  const handleCleanupMessagesDefaultChange = (checked: boolean) => {
    if (checked) {
      setCleanupMessages(null);
    } else {
      const current = cleanupMessages();
      if (current !== null) {
        setCleanupMessages(current);
      } else {
        setCleanupMessages([]);
      }
    }
  };

  createEffect(() => {
    const chatId = currentChatId();
    const chats = chatsQuery.data?.success ? chatsQuery.data.payload : [];
    const currentChat = chats.find((chat) => chat.id === chatId);
    if (currentChat) {
      setTakenOver(currentChat.takenOver);
    }
  });

  createEffect(() => {
    if (query.data?.success) {
      const scheme = query.data.payload;
      setId(scheme.id);
      setType(scheme.type);
      setTypeItems(scheme.typeItems);
      setTimeout(scheme.timeout);
      setKillStrategy(scheme.killStrategy);
      setFallbackKillStrategy(scheme.fallbackKillStrategy);
      setKillStrategyItems(scheme.killStrategyItems);
      setMentionText(scheme.mentionText);
      setMentionTextItems(scheme.mentionTextItems);
      setImageChoicesCount(scheme.imageChoicesCount);
      setImageChoicesCountItems(scheme.imageChoicesCountItems);
      setCleanupMessages(scheme.cleanupMessages);
      setDelayUnbanSecs(scheme.delayUnbanSecs);
      setPrevScheme(scheme);
    }
  });

  const handleTakeoverChange = async () => {
    if (!currentChatCanConfigure()) return;
    const chatId = currentChatId();
    if (chatId === null) {
      return;
    }

    const nextState = !takenOver();
    setIsTakingOver(true);
    try {
      const resp = await updateTakeover(chatId, nextState);
      if (isApprovalPending(resp)) return;

      if (resp.success) {
        setTakenOver(resp.payload.takenOver);
        toaster.success({
          title: resp.payload.takenOver ? "入群验证已启用" : "入群验证已停用",
          description: resp.payload.takenOver ? "新成员进群后将进入验证流程。" : "新成员将不再自动进入验证流程。",
          duration: 3_500,
        });
        await chatsQuery.refetch();
      } else {
        toaster.error({ title: "操作未执行", description: resp.message, duration: 5_000 });
      }
    } catch (error) {
      toaster.error({ title: "操作未执行", description: error instanceof Error ? error.message : "无法连接管理服务，请稍后重试。", duration: 5_000 });
    } finally {
      setIsTakingOver(false);
    }
  };

  createEffect(() => {
    const prev = prevScheme();

    if (prev) {
      const cleanupMessagesIsChange = () => {
        const current = cleanupMessages();
        if (prev.cleanupMessages === null && current === null) {
          return false;
        } else if (prev.cleanupMessages !== null && current !== null) {
          return prev.cleanupMessages.join(",") !== current.join(",");
        } else {
          return true;
        }
      };

      const isChanged = prev.type !== type()
        || prev.timeout !== timeout()
        || prev.killStrategy !== killStrategy()
        || prev.fallbackKillStrategy !== fallbackKillStrategy()
        || prev.mentionText !== mentionText()
        || prev.imageChoicesCount !== imageChoicesCount()
        || cleanupMessagesIsChange()
        || prev.delayUnbanSecs !== delayUnbanSecs();

      setIsChanged(isChanged);
    }
  });

  const handleSave = async () => {
    if (!currentChatCanConfigure()) return;
    setIsSaving(true);
    const schemeId = id();
    if (schemeId === null) {
      setIsSaving(false);
      return;
    }

    const systemToNull = (value: string | null) => {
      if (value === "system") {
        return null;
      } else {
        return value;
      }
    };

    try {
      const resp = await updateScheme(schemeId, {
        type: systemToNull(type()),
        timeout: timeout(),
        killStrategy: systemToNull(killStrategy()),
        fallbackKillStrategy: systemToNull(fallbackKillStrategy()),
        mentionText: systemToNull(mentionText()),
        imageChoicesCount: systemToNull(imageChoicesCount()),
        cleanupMessages: cleanupMessages(),
        delayUnbanSecs: delayUnbanSecs(),
      });

      if (isApprovalPending(resp)) return;
      if (resp.success) {
        setPrevScheme(resp.payload);
        toaster.success({ title: "保存成功", description: "验证设置已更新", duration: 3_500 });
        await query.refetch();
      } else {
        toaster.error({ title: "保存失败", description: resp.message || "请检查验证时间和解封延时设置。", duration: 5_000 });
      }
    } catch (error) {
      toaster.error({ title: "保存失败", description: error instanceof Error ? error.message : "无法连接管理服务，请稍后重试。", duration: 5_000 });
    } finally {
      setIsSaving(false);
    }
  };

  onMount(() => {
    setTitle("安全管理");
    setCurrentPage("security");
  });

  return (
    <PageBase>
      <Show when={currentChatId() && !currentChatCanConfigure()}><OwnerOnlyNotice /></Show>
      <fieldset disabled={!currentChatCanConfigure()} class={!currentChatCanConfigure() ? "contents pointer-events-none select-none opacity-70" : "contents"}>
      <div
        class={classNames([
          "flex flex-col gap-[1.5rem]",
          {
            "pb-button-lg": isChanged(), // 避免保存按钮遮挡底部 UI
          },
        ])}
      >
        <div class="mx-auto w-full max-w-5xl">
        <div class="mb-5 rounded-2xl bg-tea-600 p-5 text-white">
          <p class="text-xs font-semibold uppercase tracking-[0.18em] text-white/65">Security</p>
          <h1 class="mt-1 text-2xl font-bold">安全管理</h1>
          <p class="mt-2 text-sm text-white/75">控制入群验证、验证失败处理和成员消息清理。</p>
        </div>
        <FieldGroup title="入群验证状态" icon="solar:shield-check-bold-duotone">
          <div class="flex items-center justify-between gap-4 rounded-2xl border border-emerald-950/8 bg-white/70 p-4">
            <div>
              <p class="font-semibold text-ink">接管新成员验证</p>
              <p class="mt-1 text-sm text-emerald-950/55">
                {takenOver() ? "当前群组已接管，成员进群后会立即收到验证。" : "当前群组未接管，成员可以直接进群。"}
              </p>
            </div>
            <button
              type="button"
              aria-pressed={takenOver()}
              disabled={isTakingOver()}
              onClick={handleTakeoverChange}
              class={classNames([
                "shrink-0 rounded-xl px-4 py-2 text-sm font-bold text-white shadow-sm transition disabled:cursor-not-allowed disabled:opacity-60",
                takenOver() ? "bg-tea-600 hover:bg-tea-700" : "bg-amber-500 hover:bg-amber-600",
              ])}
            >
              {isTakingOver() ? "处理中…" : takenOver() ? "已启用" : "立即启用"}
            </button>
          </div>
          <p class="rounded-xl bg-amber-50 px-4 py-3 text-sm leading-6 text-amber-900/75">
            启用时会检查机器人是否具备管理员、限制成员、删除消息和发送消息权限。权限不足时不会显示为已启用。
          </p>
        </FieldGroup>
        <FieldGroup title="验证配置" icon="fluent-color:lock-shield-16">
          <SelectField
            label="验证方式"
            placeholder="选择一个验证方式"
            items={typeItems()}
            onChange={handleTypeChange}
            default={type() || "system"}
          />
          <SelectField
            label="验证失败后的处理"
            placeholder="选择一个击杀方法"
            items={killStrategyItems()}
            onChange={handleKillStrategyChange}
            default={killStrategy() || "system"}
          />
          <SelectField
            label="验证超时后的处理"
            placeholder="选择一个击杀方法"
            items={killStrategyItems()}
            onChange={handleFallbackKillStrategyChange}
            default={fallbackKillStrategy() || "system"}
          />
        </FieldGroup>
        <FieldGroup title="时间配置" icon="twemoji:hourglass-not-done">
          <InputField
            label="超时时长"
            placeholder="输入数值（秒）"
            type="number"
            min={1}
            value={timeout() || ""}
            onInput={(v) => setTimeout(parseSeconds(v, 1))}
          />
          <InputField
            label="解封延时（至少45秒）"
            placeholder="输入数值（秒）"
            type="number"
            min={45}
            value={delayUnbanSecs() || ""}
            onInput={(v) => setDelayUnbanSecs(parseSeconds(v, 45))}
          />
        </FieldGroup>
        <FieldGroup title="显示配置" icon="streamline-plump-color:eye-optic">
          <SelectField
            label="提及文本"
            placeholder="选择提及文本"
            items={mentionTextItems()}
            onChange={handleMentionTextChange}
            default={mentionText() || "system"}
          />
          <SelectField
            label="答案个数（图片验证）"
            placeholder="选择答案个数"
            items={imageChoicesCountItems()}
            onChange={handleImageChoicesCountChange}
            default={imageChoicesCount()?.toString() || "system"}
          />
        </FieldGroup>
        <FieldGroup title="其它" icon="twemoji:hammer-and-wrench">
          <FieldRoot label="消息清理">
            <div class="flex gap-[1rem]">
              <Switch>
                <Match when={cleanupMessages() === null}>
                  <Checkbox
                    label="系统默认"
                    default={true}
                    onChange={handleCleanupMessagesDefaultChange}
                  />
                </Match>
                <Match when={true}>
                  <Checkbox
                    label="加入群组"
                    default={(cleanupMessages() || []).includes("joined")}
                    onChange={(checked) => handleCleanupMessagesChange("joined", checked)}
                  />
                  <Checkbox
                    label="退出群组"
                    default={(cleanupMessages() || []).includes("left")}
                    onChange={(checked) => handleCleanupMessagesChange("left", checked)}
                  />
                  <Checkbox
                    label="系统默认"
                    default={cleanupMessages() === null}
                    onChange={handleCleanupMessagesDefaultChange}
                  />
                </Match>
              </Switch>
            </div>
          </FieldRoot>
        </FieldGroup>
      </div>
      <Show when={isChanged()}>
      <div class="fixed bottom-navigation left-0 right-0 z-20 border-t border-emerald-950/8 bg-white/92 px-3 py-3 shadow-[0_-10px_30px_rgba(23,61,49,0.08)] backdrop-blur lg:bottom-4 lg:left-[18rem] lg:right-6 lg:rounded-2xl lg:border">
        <ActionButton
          onClick={handleSave}
          loading={isSaving()}
          disabled={!isChanged()}
          variant="info"
          size="lg"
          fullWidth
        >
          保存更改
        </ActionButton>
      </div>
      </Show>
      </div>
      </fieldset>
    </PageBase>
  );
};
