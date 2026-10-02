declare namespace InputData {
  type Scheme = { type: string | null; timeout: number | null; killStrategy: string | null; fallbackKillStrategy: string | null; mentionText: string | null; imageChoicesCount: string | null; cleanupMessages: MessageKind[] | null; delayUnbanSecs: number | null; };
  type StatsRange = "today" | "7d" | "28d" | "90d";
  type Custom = { chatId?: number | null; title: string; answers: string[]; attachment: string | null; };
  type VerificationKillAction = "manual_ban" | "manual_kick" | "unban";
  type Automation = { auto_delete_bot_messages: boolean; bot_message_delete_after_seconds: number; welcome_enabled: boolean; welcome_text: string; welcome_delete_after_seconds: number; forbidden_enabled: boolean; forbidden_escalation_enabled: boolean; forbidden_warning_text: string; forbidden_warning_delete_after_seconds: number; message_templates: Record<string, string>; };
  type ForbiddenWord = { word: string; match_mode: "contains" | "exact" | "prefix"; case_sensitive: boolean; enabled: boolean; warning_text: string; action: "delete_warn" | "mute_10m" | "mute_1h" | "ban"; };
  type KeywordReplyButton = { text: string; url: string; };
  type KeywordReply = { keywords: string[]; keyword?: string; match_mode: "contains" | "exact" | "prefix"; case_sensitive: boolean; enabled: boolean; response_text: string; buttons: KeywordReplyButton[]; };
  type ForbiddenWhitelistRule = { word: string; match_mode: "contains" | "exact" | "prefix"; case_sensitive: boolean; enabled: boolean; };
  type Schedule = { title: string; text: string; schedule_type: "one_time" | "daily" | "interval"; next_run_at: string; interval_seconds: number | null; preserve_first_message: boolean; delete_after_seconds: number; enabled?: boolean; };
  type Lottery = { title: string; prize: string; description: string; winner_count: number; entry_keyword: string; end_at: string; enable_referrals: boolean; mention_all: boolean; pin_message: boolean; auto_delete_entry_messages: boolean; entry_message_delete_after_seconds: number; };
  type PermissionAccess = { readable: boolean; writable: boolean; configurable: boolean; };
}
