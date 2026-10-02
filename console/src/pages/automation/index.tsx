import { destructure } from "@solid-primitives/destructure";
import { useLocation, useNavigate } from "@solidjs/router";
import { useQuery } from "@tanstack/solid-query";
import { createEffect, createSignal, Show } from "solid-js";
import {
  cancelLottery, createForbiddenWhitelist, createForbiddenWord, createKeywordReply, createLottery, createSchedule,
  deleteForbiddenWhitelist, deleteForbiddenWord, deleteKeywordReply, deleteSchedule, drawLottery, getAutomation,
  getForbiddenWhitelist, getForbiddenWords, getKeywordReplies, getLotteries, getModerationEvents, getSchedules,
  updateAutomation, updateSchedule, testSchedule,
  updateKeywordReply,
  isApprovalPending,
} from "../../api";
import { ActionButton, OwnerOnlyNotice } from "../../components";
import { PageBase } from "../../layouts";
import { globalState } from "../../state";
import { setCurrentPage } from "../../state/global";
import { setTitle } from "../../state/meta";
import { toaster } from "../../utils";
import { LotterySettings } from "./LotterySettings";
import { MessageSettings, type MessageCategory } from "./MessageSettings";

export default () => {
  const { currentChatId, currentChatCanConfigure } = destructure(globalState);
  const location = useLocation();
  const navigate = useNavigate();
  const section = () => location.pathname.endsWith("/lottery") ? "lottery" : "messages";
  const messageCategory = (): MessageCategory => {
    const params = new URLSearchParams(location.search);
    if (params.get("mode") === "create") return "schedules";
    const category = params.get("category");
    return category === "templates" || category === "replies" || category === "moderation" || category === "schedules" ? category : "settings";
  };
  const [saving, setSaving] = createSignal(false);
  const [autoDelete, setAutoDelete] = createSignal(false);
  const [botDeleteAfter, setBotDeleteAfter] = createSignal(0);
  const [welcomeEnabled, setWelcomeEnabled] = createSignal(false);
  const [welcomeText, setWelcomeText] = createSignal("");
  const [welcomeDeleteAfter, setWelcomeDeleteAfter] = createSignal(0);
  const [forbiddenEnabled, setForbiddenEnabled] = createSignal(false);
  const [escalationEnabled, setEscalationEnabled] = createSignal(false);
  const [warningText, setWarningText] = createSignal("");
  const [warningDeleteAfter, setWarningDeleteAfter] = createSignal(0);
  const [messageTemplates, setMessageTemplates] = createSignal<Record<string, string>>({});

  const automationQuery = useQuery(() => ({ queryKey: ["automation", currentChatId()], queryFn: () => getAutomation(currentChatId()!), enabled: currentChatId() != null }));
  const wordsQuery = useQuery(() => ({ queryKey: ["forbidden-words", currentChatId()], queryFn: () => getForbiddenWords(currentChatId()!), enabled: currentChatId() != null }));
  const keywordRepliesQuery = useQuery(() => ({ queryKey: ["keyword-replies", currentChatId()], queryFn: () => getKeywordReplies(currentChatId()!), enabled: currentChatId() != null }));
  const whitelistQuery = useQuery(() => ({ queryKey: ["forbidden-whitelist", currentChatId()], queryFn: () => getForbiddenWhitelist(currentChatId()!), enabled: currentChatId() != null }));
  const moderationQuery = useQuery(() => ({ queryKey: ["moderation-events", currentChatId()], queryFn: () => getModerationEvents(currentChatId()!), enabled: currentChatId() != null }));
  const schedulesQuery = useQuery(() => ({ queryKey: ["schedules", currentChatId()], queryFn: () => getSchedules(currentChatId()!), enabled: currentChatId() != null }));
  const lotteriesQuery = useQuery(() => ({ queryKey: ["lotteries", currentChatId()], queryFn: () => getLotteries(currentChatId()!), enabled: currentChatId() != null }));
  const automationReady = () => automationQuery.data?.success && automationQuery.data.payload.chatId === currentChatId();

  createEffect(() => {
    const data = automationQuery.data;
    if (!data?.success) return;
    setAutoDelete(data.payload.autoDeleteBotMessages);
    setBotDeleteAfter(data.payload.botMessageDeleteAfterSeconds);
    setWelcomeEnabled(data.payload.welcomeEnabled);
    setWelcomeText(data.payload.welcomeText || "");
    setWelcomeDeleteAfter(data.payload.welcomeDeleteAfterSeconds);
    setForbiddenEnabled(data.payload.forbiddenEnabled);
    setEscalationEnabled(data.payload.forbiddenEscalationEnabled);
    setWarningText(data.payload.forbiddenWarningText || "");
    setWarningDeleteAfter(data.payload.forbiddenWarningDeleteAfterSeconds);
    setMessageTemplates(data.payload.messageTemplates || {});
  });

  createEffect(() => {
    setCurrentPage(section() === "lottery" ? "lottery" : "messages");
    setTitle(section() === "lottery" ? "抽奖中心" : categoryTitle(messageCategory()));
  });

  const save = async () => {
    if (!currentChatId() || !currentChatCanConfigure()) return;
    setSaving(true);
    try {
      const response = await updateAutomation(currentChatId()!, {
        auto_delete_bot_messages: autoDelete(), bot_message_delete_after_seconds: botDeleteAfter(),
        welcome_enabled: welcomeEnabled(), welcome_text: welcomeText(), welcome_delete_after_seconds: welcomeDeleteAfter(),
        forbidden_enabled: forbiddenEnabled(), forbidden_escalation_enabled: escalationEnabled(),
        forbidden_warning_text: warningText(), forbidden_warning_delete_after_seconds: warningDeleteAfter(),
        message_templates: normalizeMessageTemplateKeys(messageTemplates()),
      });
      if (isApprovalPending(response)) return;
      if (response.success) {
        toaster.success({ title: "保存成功", description: "消息管理设置已生效", duration: 3_500 });
        await automationQuery.refetch();
      } else {
        toaster.error({ title: "保存失败", description: response.message, duration: 5_000 });
      }
    } catch (error) {
      toaster.error({ title: "保存失败", description: error instanceof Error ? error.message : "无法连接管理服务，请稍后重试。", duration: 5_000 });
    } finally {
      setSaving(false);
    }
  };

  return (
    <PageBase>
      <Show when={currentChatId()} fallback={<p class="panel-muted text-center">请先在左上角选择群组</p>}>
        <div class="mx-auto max-w-6xl space-y-5">
          <Show when={section() === "messages"}>
            <Show when={!currentChatCanConfigure()}><OwnerOnlyNotice /></Show>
            <Show when={automationReady()} fallback={<div class="rounded-2xl bg-white p-6 text-center"><p class="panel-muted">{automationQuery.isLoading ? "正在读取当前群组的消息设置…" : automationQuery.data?.success === false ? automationQuery.data.message : "消息设置暂时无法读取。"}</p><Show when={!automationQuery.isLoading}><div class="mt-3"><ActionButton variant="info" outline onClick={() => automationQuery.refetch()}>重新读取</ActionButton></div></Show></div>}>
            <MessageSettings
              readOnly={!currentChatCanConfigure()}
              activeCategory={messageCategory()} onCategoryChange={(value) => navigate(`/messages?category=${value}`)}
              autoDelete={autoDelete()} botDeleteAfter={botDeleteAfter()} setAutoDelete={setAutoDelete} setBotDeleteAfter={setBotDeleteAfter}
              welcomeEnabled={welcomeEnabled()} welcomeText={welcomeText()} welcomeDeleteAfter={welcomeDeleteAfter()} setWelcomeEnabled={setWelcomeEnabled} setWelcomeText={setWelcomeText} setWelcomeDeleteAfter={setWelcomeDeleteAfter}
              forbiddenEnabled={forbiddenEnabled()} escalationEnabled={escalationEnabled()} warningText={warningText()} warningDeleteAfter={warningDeleteAfter()} setForbiddenEnabled={setForbiddenEnabled} setEscalationEnabled={setEscalationEnabled} setWarningText={setWarningText} setWarningDeleteAfter={setWarningDeleteAfter}
              messageTemplates={messageTemplates()} messageTemplateCatalog={automationQuery.data?.success ? automationQuery.data.payload.messageTemplateCatalog : []} setMessageTemplate={(key, value) => setMessageTemplates((current) => ({ ...current, [key]: value }))}
              words={wordsQuery.data?.success ? wordsQuery.data.payload : []} whitelist={whitelistQuery.data?.success ? whitelistQuery.data.payload : []} events={moderationQuery.data?.success ? moderationQuery.data.payload : []}
              keywordReplies={keywordRepliesQuery.data?.success ? keywordRepliesQuery.data.payload : []}
              schedules={schedulesQuery.data?.success ? schedulesQuery.data.payload : []}
              onAddWord={async (input) => { const response = await createForbiddenWord(currentChatId()!, input); if (response.success) await Promise.all([wordsQuery.refetch(), moderationQuery.refetch()]); return response; }}
              onRemoveWord={async (id) => { const response = await deleteForbiddenWord(currentChatId()!, id); if (response.success) await wordsQuery.refetch(); return response; }}
              onAddWhitelist={async (input) => { const response = await createForbiddenWhitelist(currentChatId()!, input); if (response.success) await whitelistQuery.refetch(); return response; }}
              onRemoveWhitelist={async (id) => { const response = await deleteForbiddenWhitelist(currentChatId()!, id); if (response.success) await whitelistQuery.refetch(); return response; }}
              onRefreshEvents={() => moderationQuery.refetch()}
              onAddKeywordReply={async (input) => { const response = await createKeywordReply(currentChatId()!, input); if (response.success) await keywordRepliesQuery.refetch(); return response; }}
              onUpdateKeywordReply={async (id, input) => { const response = await updateKeywordReply(currentChatId()!, id, input); if (response.success) await keywordRepliesQuery.refetch(); return response; }}
              onRemoveKeywordReply={async (id) => { const response = await deleteKeywordReply(currentChatId()!, id); if (response.success) await keywordRepliesQuery.refetch(); return response; }}
              onAddSchedule={async (input) => { const response = await createSchedule(currentChatId()!, input); if (response.success) await schedulesQuery.refetch(); return response; }}
              onUpdateSchedule={async (id, input) => { const response = await updateSchedule(currentChatId()!, id, input); if (response.success) await schedulesQuery.refetch(); return response; }}
              onTestSchedule={async (id) => { const response = await testSchedule(currentChatId()!, id); if (response.success) await schedulesQuery.refetch(); return response; }}
              onRemoveSchedule={async (id) => { const response = await deleteSchedule(currentChatId()!, id); if (response.success) await schedulesQuery.refetch(); return response; }}
            />
            <Show when={currentChatCanConfigure() && !["replies", "schedules"].includes(messageCategory())}>
              <ActionButton variant="info" size="lg" fullWidth loading={saving()} onClick={save}>{categorySaveLabel(messageCategory())}</ActionButton>
            </Show>
            </Show>
          </Show>
          <Show when={section() === "lottery"}>
            <LotterySettings
              chatId={currentChatId()!} items={lotteriesQuery.data?.success ? lotteriesQuery.data.payload : []}
              onCreate={async (input) => { const response = await createLottery(currentChatId()!, input); if (response.success) await lotteriesQuery.refetch(); return response; }}
              onDraw={async (id) => { const response = await drawLottery(currentChatId()!, id); if (response.success) await lotteriesQuery.refetch(); return response; }}
              onCancel={async (id) => { const response = await cancelLottery(currentChatId()!, id); if (response.success) await lotteriesQuery.refetch(); return response; }}
            />
          </Show>
        </div>
      </Show>
    </PageBase>
  );
};

const categoryTitle = (category: MessageCategory) => ({ settings: "消息设置", templates: "机器人文案", replies: "关键词自动回复", moderation: "违禁词管理", schedules: "定时消息" }[category]);
const categorySaveLabel = (category: MessageCategory) => ({ settings: "保存消息设置", templates: "保存机器人文案", replies: "", moderation: "保存违禁词设置", schedules: "" }[category]);

const normalizeMessageTemplateKeys = (templates: Record<string, string>) => Object.fromEntries(
  Object.entries(templates).map(([key, value]) => [key.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`), value]),
);
