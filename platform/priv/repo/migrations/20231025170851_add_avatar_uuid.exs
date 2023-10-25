defmodule Platform.Repo.Migrations.AddAvatarUuid do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :avatar_uuid, :binary_id, null: true
    end
  end
end
