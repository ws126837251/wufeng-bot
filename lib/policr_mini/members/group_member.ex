defmodule PolicrMini.Members.GroupMember do
  @moduledoc false

  use PolicrMini.Schema

  alias PolicrMini.Instances.Chat
  alias PolicrMini.Schema.User

  @required_fields ~w(chat_id user_id status source is_bot)a

  schema "group_members" do
    belongs_to :chat, Chat
    belongs_to :user, User

    field :status, :string
    field :source, :string
    field :is_bot, :boolean, default: false

    timestamps()
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, ~w(unknown member restricted creator administrator left kicked))
    |> unique_constraint([:chat_id, :user_id], name: :group_members_chat_user_unique)
  end
end
