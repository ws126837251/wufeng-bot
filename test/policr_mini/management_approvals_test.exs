defmodule PolicrMini.ManagementApprovalsTest do
  use ExUnit.Case, async: true

  alias PolicrMini.ManagementApprovals

  test "distinguishes Telegram owners and administrators" do
    assert ManagementApprovals.member_role(%{status: "creator"}) == :owner
    assert ManagementApprovals.member_role(%{status: "administrator"}) == :administrator
    assert ManagementApprovals.member_role(%{status: "member"}) == :member
  end

  test "only the current owner bypasses management approval" do
    refute ManagementApprovals.approval_required?(:owner)
    assert ManagementApprovals.approval_required?(:administrator)
    assert ManagementApprovals.approval_required?(:member)
  end
end
