defmodule PolicrMini.MembersTest do
  use ExUnit.Case, async: true

  alias PolicrMini.Members

  describe "protect_target/2" do
    test "protects WuFengBot itself" do
      assert {:error, :bot_protected} =
               Members.protect_target(%{status: "member", user: %{id: 100, is_bot: true}}, 100)

      assert :ok =
               Members.protect_target(%{status: "member", user: %{id: 200, is_bot: true}}, 100)
    end

    test "protects group owners and administrators" do
      assert {:error, :admin_protected} =
               Members.protect_target(%{status: "creator", user: %{id: 200, is_bot: false}}, 100)

      assert {:error, :admin_protected} =
               Members.protect_target(
                 %{status: "administrator", user: %{id: 200, is_bot: false}},
                 100
               )
    end

    test "rejects users who are no longer members" do
      assert {:error, :not_a_member} =
               Members.protect_target(%{status: "left", user: %{id: 200, is_bot: false}}, 100)

      assert {:error, :not_a_member} =
               Members.protect_target(%{
                 status: "restricted",
                 is_member: false,
                 user: %{id: 200, is_bot: false}
               }, 100)
    end

    test "allows regular and restricted members" do
      assert :ok =
               Members.protect_target(%{status: "member", user: %{id: 200, is_bot: false}}, 100)

      assert :ok =
               Members.protect_target(%{
                 status: "restricted",
                 is_member: true,
                 user: %{id: 200, is_bot: false}
               }, 100)
    end
  end
end
