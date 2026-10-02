import { retrieveRawInitData } from "@telegram-apps/sdk";
import axios, { AxiosResponse } from "axios";
import camelcaseKeys from "camelcase-keys";
import { blockConsoleSession } from "./state/session";
import { toaster } from "./utils/toaster";

type PayloadType<T> = Promise<ApiResponse<T>>;
const BASE_URL = "/console/v2/api";
export const client = axios.create({ baseURL: BASE_URL, timeout: 15_000, validateStatus: () => true });
client.interceptors.request.use((config) => { const authorization = tmaAuthorization(); if (authorization) config.headers.Authorization = authorization; return config; });
client.interceptors.response.use(
  (response) => {
    if (response.data?.approval_pending === true) {
      toaster.success({
        title: "已提交群主审批",
        description: response.data.message || "群主在 WuFengBot 私聊中点击同意后，操作才会执行。",
        duration: 3500,
      });
    }
    if (response.status === 401) {
      blockConsoleSession("expired");
    } else if (response.status === 403) {
      toaster.error({ title: "没有权限", description: response.data?.message || "当前 Telegram 账号没有管理这个群组的权限。", duration: 5_000 });
    } else if (response.status >= 400) {
      toaster.error({
        title: response.status >= 500 ? "服务暂时不可用" : "操作未执行",
        description: response.data?.message || `服务器返回 HTTP ${response.status}，请稍后重试。`,
        duration: 5_000,
      });
    }
    return response;
  },
  (error) => {
    const message = error.code === "ECONNABORTED"
      ? "服务器 15 秒内没有响应，本次操作没有确认成功。请稍后重试。"
      : "无法连接管理面板服务，请稍后重试。";
    if (error.code === "ECONNABORTED") {
      toaster.error({ title: "请求超时", description: message, duration: 5_000 });
    } else {
      toaster.error({ title: "连接失败", description: message, duration: 5_000 });
    }
    return {
      data: { success: false, message },
      status: 0,
      statusText: "Network Error",
      headers: {},
      config: error.config || {},
    } as AxiosResponse;
  },
);
function tmaAuthorization(): string | undefined { try { return `tma ${retrieveRawInitData()}`; } catch (error) { if (error instanceof Error && error.name === "LaunchParamsRetrieveError") return undefined; throw error; } }
export async function getServerInfo(): PayloadType<ServerData.ServerInfo> { return strictify(await client.get("")); }
export async function getMe(): PayloadType<ServerData.User> { return strictify(await client.get("/users/me")); }
export async function getChats(): PayloadType<ServerData.Chat[]> { return strictify(await client.get("/chats")); }
export async function copyManagementSettings(chatId: number, sourceChatId: number) { return strictify(await client.post(`/chats/${chatId}/copy-settings`, { source_chat_id: sourceChatId })); }
export async function getPermissions(chatId: number): PayloadType<ServerData.PermissionAccess[]> { return strictify(await client.get(`/chats/${chatId}/permissions`)); }
export async function updatePermission(chatId: number, userId: number, input: InputData.PermissionAccess): PayloadType<ServerData.PermissionAccess> { return strictify(await client.put(`/chats/${chatId}/permissions/${userId}`, input)); }
export async function getMembers(chatId: number, query = ""): PayloadType<ServerData.Member[]> { return strictify(await client.get(`/chats/${chatId}/members`, { params: { query } })); }
export async function getMemberSync(chatId: number): PayloadType<ServerData.MemberSync> { return strictify(await client.get(`/chats/${chatId}/member-sync`)); }
export async function syncMembers(chatId: number): PayloadType<ServerData.MemberSync> { return strictify(await client.post(`/chats/${chatId}/member-sync`)); }
export async function getMemberActions(chatId: number): PayloadType<ServerData.MemberAction[]> { return strictify(await client.get(`/chats/${chatId}/member-actions`)); }
export async function getMemberBlacklist(chatId: number): PayloadType<ServerData.MemberBlacklistEntry[]> { return strictify(await client.get(`/chats/${chatId}/member-blacklist`)); }
export async function blacklistMember(chatId: number, userId: number, reason: string): PayloadType<ServerData.Member> { return strictify(await client.post(`/chats/${chatId}/members/${userId}/blacklist`, { reason })); }
export async function unblockMember(chatId: number, userId: number): PayloadType<ServerData.MemberBlacklistEntry> { return strictify(await client.post(`/chats/${chatId}/member-blacklist/${userId}/unblock`)); }
export async function updateTakeover(chatId: number, enabled: boolean): PayloadType<ServerData.Chat> { return strictify(await client.put(`/chats/${chatId}/takeover`, { value: enabled })); }
export async function queryStats(chatId: number, range: InputData.StatsRange): PayloadType<ServerData.Stats> { return strictify(await client.get(`/chats/${chatId}/stats?range=${range}`)); }
export async function getChatHealth(chatId: number): PayloadType<ServerData.ChatHealth> { return strictify(await client.get(`/chats/${chatId}/health`)); }
export async function getScheme(chatId: number): PayloadType<ServerData.Scheme> { return strictify(await client.get(`/chats/${chatId}/scheme`)); }
export async function getCustoms(chatId: number): PayloadType<ServerData.CustomItem[]> { return strictify(await client.get(`/chats/${chatId}/customs`)); }
export async function getAutomation(chatId: number): PayloadType<ServerData.Automation> { return strictify(await client.get(`/chats/${chatId}/automation`)); }
export async function updateAutomation(chatId: number, input: InputData.Automation) { return strictify(await client.put(`/chats/${chatId}/automation`, input)); }
export async function getForbiddenWords(chatId: number): PayloadType<ServerData.ForbiddenWord[]> { return strictify(await client.get(`/chats/${chatId}/forbidden-words`)); }
export async function createForbiddenWord(chatId: number, input: InputData.ForbiddenWord) { return strictify(await client.post(`/chats/${chatId}/forbidden-words`, input)); }
export async function deleteForbiddenWord(chatId: number, id: number) { return strictify(await client.delete(`/chats/${chatId}/forbidden-words/${id}`)); }
export async function getKeywordReplies(chatId: number): PayloadType<ServerData.KeywordReply[]> { return strictify(await client.get(`/chats/${chatId}/keyword-replies`)); }
export async function createKeywordReply(chatId: number, input: InputData.KeywordReply) { return strictify(await client.post(`/chats/${chatId}/keyword-replies`, input)); }
export async function updateKeywordReply(chatId: number, id: number, input: InputData.KeywordReply) { return strictify(await client.put(`/chats/${chatId}/keyword-replies/${id}`, input)); }
export async function deleteKeywordReply(chatId: number, id: number) { return strictify(await client.delete(`/chats/${chatId}/keyword-replies/${id}`)); }
export async function getForbiddenWhitelist(chatId: number): PayloadType<ServerData.ForbiddenWhitelistRule[]> { return strictify(await client.get(`/chats/${chatId}/forbidden-whitelist`)); }
export async function createForbiddenWhitelist(chatId: number, input: InputData.ForbiddenWhitelistRule) { return strictify(await client.post(`/chats/${chatId}/forbidden-whitelist`, input)); }
export async function deleteForbiddenWhitelist(chatId: number, id: number) { return strictify(await client.delete(`/chats/${chatId}/forbidden-whitelist/${id}`)); }
export async function getModerationEvents(chatId: number): PayloadType<ServerData.ModerationEvent[]> { return strictify(await client.get(`/chats/${chatId}/moderation-events`)); }
export async function getSchedules(chatId: number): PayloadType<ServerData.Schedule[]> { return strictify(await client.get(`/chats/${chatId}/schedules`)); }
export async function createSchedule(chatId: number, input: InputData.Schedule) { return strictify(await client.post(`/chats/${chatId}/schedules`, input)); }
export async function updateSchedule(chatId: number, id: number, input: Partial<InputData.Schedule>) { return strictify(await client.put(`/chats/${chatId}/schedules/${id}`, input)); }
export async function testSchedule(chatId: number, id: number) { return strictify(await client.post(`/chats/${chatId}/schedules/${id}/test`)); }
export async function deleteSchedule(chatId: number, id: number) { return strictify(await client.delete(`/chats/${chatId}/schedules/${id}`)); }
export async function getLotteries(chatId: number): PayloadType<ServerData.Lottery[]> { return strictify(await client.get(`/chats/${chatId}/lotteries`)); }
export async function getLotteryEntries(chatId: number, lotteryId: number): PayloadType<ServerData.LotteryEntry[]> { return strictify(await client.get(`/chats/${chatId}/lotteries/${lotteryId}/entries`)); }
export async function getLotteryAudit(chatId: number, lotteryId: number): PayloadType<ServerData.LotteryAudit> { return strictify(await client.get(`/chats/${chatId}/lotteries/${lotteryId}/audit`)); }
export async function createLottery(chatId: number, input: InputData.Lottery) { return strictify(await client.post(`/chats/${chatId}/lotteries`, input)); }
export async function drawLottery(chatId: number, id: number) { return strictify(await client.post(`/chats/${chatId}/lotteries/${id}/draw`)); }
export async function cancelLottery(chatId: number, id: number) { return strictify(await client.post(`/chats/${chatId}/lotteries/${id}/cancel`)); }
export async function deleteCustom(id: number): PayloadType<ServerData.CustomItem> { return strictify(await client.delete(`/customs/${id}`)); }
export async function saveCustom({ id, custom }: { id: number | null; custom: InputData.Custom }) { return id !== null ? updateCustom(id, custom) : createCustom(custom); }
export async function createCustom(custom: InputData.Custom) { return strictify(await client.post("/customs", { chat_id: custom.chatId, title: custom.title, answers: custom.answers, attachment: custom.attachment })); }
export async function updateCustom(id: number, custom: InputData.Custom) { return strictify(await client.put(`/customs/${id}`, { title: custom.title, answers: custom.answers, attachment: custom.attachment })); }
export async function getVerifications(chatId: number, range: string): PayloadType<ServerData.Verification[]> { return strictify(await client.get(`/chats/${chatId}/verifications?range=${range}`)); }
export async function getOperations(chatId: number, range: string): PayloadType<ServerData.Operation[]> { return strictify(await client.get(`/chats/${chatId}/operations?range=${range}`)); }
export async function updateScheme(id: number, scheme: InputData.Scheme): PayloadType<ServerData.Scheme> { return strictify(await client.put(`/schemes/${id}`, { type: scheme.type, timeout: scheme.timeout, kill_strategy: scheme.killStrategy, fallback_kill_strategy: scheme.fallbackKillStrategy, mention_text: scheme.mentionText, image_choices_count: scheme.imageChoicesCount, cleanup_messages: scheme.cleanupMessages, delay_unban_secs: scheme.delayUnbanSecs })); }
export async function killFromVerification(id: number, action: InputData.VerificationKillAction): PayloadType<ServerData.Verification> { return strictify(await client.put(`/verifications/${id}/kill`, { action })); }
async function strictify<T extends Record<string, unknown> | readonly Record<string, unknown>[]>(resp: AxiosResponse<T>): Promise<ApiResponse<T>> {
  const normalized = typeof resp.data === "object" && resp.data !== null
    ? camelcaseKeys(resp.data, { deep: true }) as unknown as ApiResponse<T>
    : null;

  if (resp.status >= 400) {
    if (normalized && "success" in normalized) return normalized;
    return {
      success: false as const,
      message: `请求失败（HTTP ${resp.status}）`,
    };
  }

  return normalized || { success: false as const, message: "服务器返回了无法识别的数据。" };
}

export function isApprovalPending(response: unknown): boolean {
  return typeof response === "object" && response !== null && "approvalPending" in response && response.approvalPending === true;
}
