defmodule Platform.Repo.Migrations.AddAssigneesToMedia do
  use Ecto.Migration

  def change do
    create table(:media_assignments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :media_id, references(:media, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      timestamps()
    end

    create index(:media_assignments, [:media_id])
    create index(:media_assignments, [:user_id])
    create unique_index(:media_assignments, [:media_id, :user_id])
  end
end
