defmodule Platform.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :code, :string

      timestamps()
    end

    alter table(:media) do
      add :project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
