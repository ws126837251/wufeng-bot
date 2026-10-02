defmodule PolicrMiniBot.BootHelper do
  @moduledoc false

  alias PolicrMiniBot.Info

  require Logger

  @spec fetch_bot_info :: Info.t()
  def fetch_bot_info do
    # 由于 Instance 缓存的需要，此处须使用 `Telegex.Instance.get_me/0` 不能使用 `Telegex.get_me/0`。
    case Telegex.Instance.fetch_me() do
      {:ok, %Telegex.Type.User{id: id, username: username, first_name: first_name}} ->
        %Info{
          id: id,
          username: username,
          name: first_name,
          # TODO: 此处对头像的获取添加超时重试。
          photo_file_id: get_avatar_file_id(id),
          is_third_party: username not in PolicrMiniBot.official_bots()
        }

      {:error, %{reason: :timeout}} ->
        Logger.warning("Checking bot information timeout, retrying...")
        :timer.sleep(100)

        fetch_bot_info()

      {:error, %{reason: :closed}} ->
        Logger.warning("Network error while checking bot information, retrying...")
        :timer.sleep(100)

        fetch_bot_info()

      {:error, e} ->
        raise e
    end
  end

  @spec get_avatar_file_id(integer) :: binary | nil
  defp get_avatar_file_id(user_id) do
    case Telegex.get_user_profile_photos(user_id) do
      {:ok, %{photos: [[%{file_id: file_id} | _]]}} ->
        file_id

      _ ->
        nil
    end
  end

  def gen_commands(_username) do
    alias Telegex.Type.BotCommand

    private_commands = [
      %BotCommand{
        command: "start",
        description: "打开 WuFengBot"
      },
      %BotCommand{
        command: "relay",
        description: "联系客服（无法私聊请点击）"
      }
    ]

    group_commands = [
      %BotCommand{command: "lottery", description: "创建抽奖"},
      %BotCommand{command: "draw", description: "立即开奖"},
      %BotCommand{command: "active", description: "正在抽奖"},
      %BotCommand{command: "ban", description: "踢出并永久拉黑成员"},
      %BotCommand{command: "manage", description: "打开群管理快捷面板"},
      %BotCommand{command: "status", description: "检查机器人和权限状态"}
    ]

    with {:ok, true} <- Telegex.set_my_commands(private_commands),
         {:ok, true} <-
           Telegex.set_my_commands(private_commands, scope: %{type: "all_private_chats"}),
         {:ok, true} <-
           Telegex.set_my_commands(group_commands, scope: %{type: "all_group_chats"}) do
      :ok
    else
      error ->
        Logger.warning("Sync Telegram command menus failed: #{inspect(error)}")
        error
    end
  end

  @doc false
  def command_menu do
    %{
      private: [
        {"start", "打开 WuFengBot"},
        {"relay", "联系客服（无法私聊请点击）"}
      ],
      group: [
        {"lottery", "创建抽奖"},
        {"draw", "立即开奖"},
        {"active", "正在抽奖"},
        {"ban", "踢出并永久拉黑成员"},
        {"manage", "打开群管理快捷面板"},
        {"status", "检查机器人和权限状态"}
      ]
    }
  end
end
