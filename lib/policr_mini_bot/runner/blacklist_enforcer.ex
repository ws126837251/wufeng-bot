defmodule PolicrMiniBot.Runner.BlacklistEnforcer do
  @moduledoc false

  alias PolicrMini.Members.Blacklist

  def run, do: Blacklist.enforce_pending()
end
