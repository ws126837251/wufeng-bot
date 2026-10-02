defmodule PolicrMiniBot.Runner.VerificationReleaseFixer do
  @moduledoc false

  require Logger

  def run do
    results = PolicrMiniBot.VerificationRelease.recover_due()
    released = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))

    if released > 0 or failed > 0 do
      Logger.info(
        "Verification release check finished: #{inspect(released: released, failed: failed)}"
      )
    end

    :done
  end
end
