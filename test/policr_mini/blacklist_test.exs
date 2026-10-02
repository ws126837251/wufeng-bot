defmodule PolicrMini.Members.BlacklistTest do
  use PolicrMini.DataCase, async: true

  alias PolicrMini.Members.Blacklist

  @chat_id -100_123_456_789
  @actor_id 123_456
  @user %{id: 987_654, first_name: "测试", last_name: "成员", username: "test_member"}

  test "stores active blacklist entries separately by chat" do
    assert {:ok, _entry} = Blacklist.put(@chat_id, @actor_id, @user, "发布广告")
    assert Blacklist.active?(@chat_id, @user.id)
    refute Blacklist.active?(-100_999, @user.id)

    assert [entry] = Blacklist.list(@chat_id)
    assert entry.user_id == @user.id
    assert entry.full_name == "测试 成员"
    assert entry.reason == "发布广告"
    assert entry.enforced_at == nil
  end

  test "upserting a previous entry reactivates it and refreshes its reason" do
    assert {:ok, _entry} = Blacklist.put(@chat_id, @actor_id, @user, "旧原因")
    assert {:ok, _entry} = Blacklist.put(@chat_id, @actor_id + 1, @user, "新原因")

    assert [entry] = Blacklist.list(@chat_id)
    assert entry.actor_user_id == @actor_id + 1
    assert entry.reason == "新原因"
  end

  test "recognizes only Telegram's kicked status as an enforced ban" do
    assert Blacklist.banned_member?(%{status: "kicked"})
    refute Blacklist.banned_member?(%{status: "member"})
    refute Blacklist.banned_member?(%{status: "left"})
  end
end
