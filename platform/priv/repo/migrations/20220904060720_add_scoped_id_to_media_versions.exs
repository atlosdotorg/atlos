defmodule Platform.Repo.Migrations.AddScopedIdToMediaVersions do
  use Ecto.Migration
  alias Platform.Material

  def change do
    alter table(:media_versions) do
      add :scoped_id, :integer
    end

    create unique_index(:media_versions, [:scoped_id, :media_id],
             name: "media_versions_scoped_id_index"
           )
  end
end
