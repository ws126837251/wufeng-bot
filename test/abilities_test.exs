defmodule AbilitiesTest do
  use PolicrMini.DataCase

  alias PolicrMini.{Factory, Instances, PermissionBusiness, UserBusiness}
  alias PolicrMini.Chats.{CustomKit, Scheme, Verification}

  setup do
    {:ok, chat} = Instances.create_chat(Factory.build(:chat) |> Map.from_struct())
    {:ok, user} = UserBusiness.create(Factory.build(:user) |> Map.from_struct())
    %{chat: chat, user: user}
  end

  test "普通管理员可以执行功能但不能修改群配置", %{chat: chat, user: user} do
    insert_permission(chat.id, user.id, tg_is_owner: false, writable: true)

    assert Canada.Can.can?(user, :show, chat)
    assert Canada.Can.can?(user, :create, chat)
    assert Canada.Can.can?(user, :draw, chat)
    assert Canada.Can.can?(user, :cancel, chat)
    assert Canada.Can.can?(user, :members, chat)
    assert Canada.Can.can?(user, :kick_member, chat)
    refute Canada.Can.can?(user, :update, chat)
    refute Canada.Can.can?(user, :add_schedule, chat)
    refute Canada.Can.can?(user, :update, %Scheme{chat_id: chat.id})
    refute Canada.Can.can?(user, :add, %CustomKit{chat_id: chat.id})
    assert Canada.Can.can?(user, :kill, %Verification{chat_id: chat.id})
  end

  test "群主可以修改群配置并执行功能", %{chat: chat, user: user} do
    insert_permission(chat.id, user.id, tg_is_owner: true, writable: true)

    assert Canada.Can.can?(user, :update, chat)
    assert Canada.Can.can?(user, :add_schedule, chat)
    assert Canada.Can.can?(user, :update, %Scheme{chat_id: chat.id})
    assert Canada.Can.can?(user, :add, %CustomKit{chat_id: chat.id})
    assert Canada.Can.can?(user, :create, chat)
    assert Canada.Can.can?(user, :kick_member, chat)
  end

  defp insert_permission(chat_id, user_id, attrs) do
    Factory.build(:permission, [chat_id: chat_id, user_id: user_id] ++ attrs)
    |> Map.from_struct()
    |> PermissionBusiness.create()
  end
end
