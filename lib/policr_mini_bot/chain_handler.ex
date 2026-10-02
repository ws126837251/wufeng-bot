defmodule PolicrMiniBot.ChainHandler do
  @moduledoc false

  use Telegex.Chain.Handler

  pipeline([
    PolicrMiniBot.InitSendSourceChain,
    PolicrMiniBot.InitTakenOverChain,
    PolicrMiniBot.InitFromChain,
    PolicrMiniBot.TrackGroupMemberChain,
    PolicrMiniBot.InitUserJoinedActionChain,
    PolicrMiniBot.InitChatJoinRequestActionChain,
    PolicrMiniBot.HandleBlacklistedMemberChain,
    PolicrMiniBot.RespStartChain,
    PolicrMiniBot.RespRelayChain,
    PolicrMiniBot.RespLotterySettingsChain,
    PolicrMiniBot.RespLotteryDrawChain,
    PolicrMiniBot.RespLotteryActiveChain,
    PolicrMiniBot.RespMemberBlacklistChain,
    PolicrMiniBot.RespManageChain,
    PolicrMiniBot.RespStatusChain,
    PolicrMiniBot.HandleJoinRequestChain,
    PolicrMiniBot.HandleGroupUserJoinedChain,
    PolicrMiniBot.HandleGroupMemberLeftChain,
    PolicrMiniBot.HandleLeftMessageChain,
    PolicrMiniBot.HandleSelfJoinedChain,
    PolicrMiniBot.HandleSelfLeftChain,
    PolicrMiniBot.HandleAdminPermissionsChangeChain,
    PolicrMiniBot.HandleSelfPermissionsChangeChain,
    PolicrMiniBot.HandleJoinedMessageChain,
    PolicrMiniBot.HandleLotteryMessageChain,
    PolicrMiniBot.HandleAutomationMessageChain,
    PolicrMiniBot.HandleKeywordReplyChain,
    PolicrMiniBot.HandleNewChatTitleChain,
    PolicrMiniBot.HandleNewChatPhotoChain,
    PolicrMiniBot.HandleMemberRemovedChain,
    PolicrMiniBot.HandlePrivateRelayChain,
    PolicrMiniBot.HandlePrivateAttachmentChain,
    PolicrMiniBot.RelayCallbackChain,
    PolicrMiniBot.ManagementApprovalCallbackChain,
    PolicrMiniBot.ProductBroadcastCallbackChain,
    PolicrMiniBot.LotteryCallbackChain,
    PolicrMiniBot.CallAnswerChain,
    PolicrMiniBot.CallRevokeTokenChain,
    PolicrMiniBot.CallEnableChain,
    PolicrMiniBot.CallLeaveChain
  ])
end
