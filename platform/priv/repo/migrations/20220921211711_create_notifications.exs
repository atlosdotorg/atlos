defmodule Platform.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :read, :boolean, default: false, null: false
      add :content, :text
      add :type, :string
      add :user_id, references(:users, on_delete: :delete_all)
      add :media_id, references(:media, on_delete: :delete_all)
      add :update_id, references(:updates, on_delete: :delete_all)

      timestamps()
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:user_id, "inserted_at DESC"])
    create index(:notifications, [:user_id, :read])
    create index(:notifications, [:media_id])
    create index(:notifications, [:update_id])
  end
end
