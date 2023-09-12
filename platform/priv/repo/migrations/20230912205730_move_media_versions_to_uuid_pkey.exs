defmodule Platform.Repo.Migrations.MoveMediaVersionsToUuidPkey do
  use Ecto.Migration

  def up do
    # Create a new UUID column and set it as the primary key
    alter table("media_versions") do
      add :uuid, :binary_id, default: fragment("gen_random_uuid()"), null: false
    end

    # Add a unique constraint on the new uuid column
    create unique_index("media_versions", [:uuid])

    # Create new UUID columns for all constraints
    alter table(:updates) do
      add :media_version_uuid, references("media_versions", type: :binary_id, column: :uuid), null: true
    end

    # Insert the UUIDs into the constraint columns
    execute "update updates set media_version_uuid = media_versions.uuid from media_versions where updates.media_version_id = media_versions.id", []

    # Drop the old constraint columns
    execute "ALTER TABLE updates drop constraint updates_media_version_id_fkey;"
    execute "ALTER TABLE updates drop column media_version_id;"
    rename table(:updates), :media_version_uuid, to: :media_version_id
    execute "ALTER TABLE updates RENAME CONSTRAINT updates_media_version_uuid_fkey TO updates_tokens_media_version_id_fkey;"

    # Drop the old primary key
    execute "ALTER TABLE media_versions drop constraint media_versions_pkey;"

    # Rename the old id column to integer_id, and the uuid column to id
    rename table("media_versions"), :id, to: :deprecated_integer_id
    rename table("media_versions"), :uuid, to: :id

    # Set the new primary key
    execute "ALTER TABLE media_versions ADD PRIMARY KEY (id);"
  end

  def down do
    # Irreversible
  end
end
