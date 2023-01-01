defmodule Platform.Repo.Migrations.AddProjectToUpdate do
  use Ecto.Migration

  def change do
    alter table(:updates) do
      add :project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
