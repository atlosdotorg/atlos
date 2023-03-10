defmodule Platform.Repo.Migrations.CreateProjectMemberships do
  use Ecto.Migration

  def change do
    create table(:project_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string
      add :user_id, references(:users, on_delete: :delete_all)
      add :project_id, references(:projects, on_delete: :delete_all, type: :binary_id)

      timestamps()
    end

    create index(:project_memberships, [:user_id])
    create index(:project_memberships, [:project_id])
    create unique_index(:project_memberships, [:user_id, :project_id])
  end
end
