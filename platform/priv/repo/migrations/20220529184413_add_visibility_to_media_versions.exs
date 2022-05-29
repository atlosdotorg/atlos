defmodule Platform.Repo.Migrations.AddVisibilityToMediaVersions do
  use Ecto.Migration

  def change do
    alter table(:media_versions) do
      remove :hidden
      add :visibility, :string, default: "visible"
    end
  end
end
