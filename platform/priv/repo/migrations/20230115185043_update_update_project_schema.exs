defmodule Platform.Repo.Migrations.UpdateUpdateProjectSchema do
  use Ecto.Migration

  def change do
    rename table(:updates), :project_id, to: :old_project_id

    alter table(:updates) do
      add :new_project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
