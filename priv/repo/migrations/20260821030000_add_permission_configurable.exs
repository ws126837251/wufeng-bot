defmodule PolicrMini.Repo.Migrations.AddPermissionConfigurable do
  use PolicrMini.Migration

  def change do
    alter table(:permissions) do
      add :configurable, :boolean, null: false, default: false, comment: "是否允许修改群组机器人配置"
    end
  end
end
