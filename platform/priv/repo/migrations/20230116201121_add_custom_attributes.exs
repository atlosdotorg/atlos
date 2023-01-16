defmodule Platform.Repo.Migrations.AddCustomAttributes do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :project_attributes, :map, default: %{}
    end
  end
end
