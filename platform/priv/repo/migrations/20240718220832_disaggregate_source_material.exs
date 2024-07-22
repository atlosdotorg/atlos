defmodule Platform.Repo.Migrations.DisaggregateSourceMaterial do
  use Ecto.Migration

  def change do
    alter table(:media_versions) do
      add :project_id, references(:projects, on_delete: :delete_all, type: :binary_id)
    end

    # Associate all media versions with their project
    execute """
              UPDATE media_versions
              SET project_id = media.project_id
              FROM media
              WHERE media_versions.media_id = media.id
            """,
            ""

    create table(:media_version_media, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # When either the associated media version or media is deleted, delete the
      # row. Note that this will not delete the associated media version or
      # media; it just unlinks them.
      add :media_version_id, references(:media_versions, on_delete: :delete_all, type: :binary_id)
      add :media_id, references(:media, on_delete: :delete_all, type: :binary_id)
      add :scoped_id, :integer

      timestamps()
    end

    # Create a unique constraint on media_id and scoped_id, guaranteeing that each
    # media can only have one media version with a given scoped_id.
    create unique_index(:media_version_media, [:media_id, :scoped_id])
    create unique_index(:media_version_media, [:media_id, :media_version_id])

    # Create an index that allows easily looking up media versions by media_id and media_version_id.
    create index(:media_version_media, [:media_id])
    create index(:media_version_media, [:media_version_id])

    # Populate the new table with data from the existing media_versions table. Specifically, for each media version,
    # we'll insert a row into media_version_media with the media_id, media_version_id, and scoped_id.
    execute """
              INSERT INTO media_version_media (id, media_version_id, media_id, scoped_id, inserted_at, updated_at)
              SELECT gen_random_uuid(), id, media_id, scoped_id, inserted_at, updated_at
              FROM media_versions
            """,
            ""
  end
end
