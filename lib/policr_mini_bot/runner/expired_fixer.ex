defmodule PolicrMiniBot.Runner.ExpiredFixer do
  @moduledoc false

  alias PolicrMini.Chats
  alias PolicrMini.Chats.Verification
  alias PolicrMiniBot.Worker.VerificationTerminator

  require Logger

  @spec run :: :done

  @doc """
  修正所有过期的等待验证。
  """
  def run do
    # 获取所有处于等待状态的验证
    all_expired = all_expired()

    # 修正所有状态。
    rs = Enum.map(all_expired, &expired_processing/1)
    failed_count = Enum.count(rs, &(&1 == :error))
    succeeded_count = Enum.count(rs, &(&1 == :ok))

    # 修正 x 个过期验证失败
    if failed_count > 0 do
      Logger.error("Correct #{failed_count} expired verification(s) failed")
    end

    if succeeded_count > 0 do
      Logger.warning("Corrected #{succeeded_count} expired verification(s)")
    end

    :done
  end

  defp all_expired do
    vs = Chats.find_all_pending_verifications()

    Enum.filter(vs, &expired?/1)
  end

  # 处理已过期
  def expired_processing(v) when is_struct(v, Verification) do
    # 开始修正过期验证
    Logger.debug("Start correcting expired verification: #{inspect(user_id: v.target_user_id)}",
      chat_id: v.chat_id
    )

    scheme = Chats.find_or_init_scheme!(v.chat_id)
    VerificationTerminator.terminate(v, scheme, 0)
  end

  defp expired?(v) do
    remaining_seconds = DateTime.diff(DateTime.utc_now(), v.inserted_at)
    remaining_seconds - (v.seconds + 30) > 0
  end
end
