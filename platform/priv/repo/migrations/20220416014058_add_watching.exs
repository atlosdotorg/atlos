defmodule Platform.Repo.Migrations.AddWatching do
  use Ecto.Migration

  def change do
    create table(:media_watching_users) do
      add :media_id, references(:media)
      add :user_id, references(:users)

      timestamps()
    end

    create unique_index(:media_watching_users, [:media_id, :user_id])
  end
end
