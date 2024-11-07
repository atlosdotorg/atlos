defmodule Platform.Repo.Migrations.AddArchivalDisableOption do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :source_material_archival_enabled, :boolean, default: true
    end
  end
end
