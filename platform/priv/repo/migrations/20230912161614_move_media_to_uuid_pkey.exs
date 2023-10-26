defmodule Platform.Repo.Migrations.MoveMediaToUuidPkey do
  use Ecto.Migration

  def up do
    # Create a new UUID column and set it as the primary key
    alter table("media") do
      add :uuid, :binary_id, default: fragment("gen_random_uuid()"), null: false
    end

    # Add a unique constraint on the new uuid column
    create unique_index("media", [:uuid])

    # Create new UUID columns for all constraints
    alter table(:updates) do
      add :media_uuid, references("media", type: :binary_id, column: :uuid), null: true
    end

    alter table(:media_subscriptions) do
      add :media_uuid, references("media", type: :binary_id, column: :uuid), null: true
    end

    alter table(:notifications) do
      add :media_uuid, references("media", type: :binary_id, column: :uuid), null: true
    end

    alter table(:media_versions) do
      add :media_uuid, references("media", type: :binary_id, column: :uuid), null: true
    end

    # Insert the UUIDs into the constraint columns
    execute "update updates set media_uuid = media.uuid from media where updates.media_id = media.id",
            []

    execute "update media_subscriptions set media_uuid = media.uuid from media where media_subscriptions.media_id = media.id",
            []

    execute "update notifications set media_uuid = media.uuid from media where notifications.media_id = media.id",
            []

    execute "update media_versions set media_uuid = media.uuid from media where media_versions.media_id = media.id",
            []

    # Drop the old constraint columns
    execute "ALTER TABLE updates drop constraint updates_media_id_fkey;"
    execute "ALTER TABLE updates drop column media_id;"
    rename table(:updates), :media_uuid, to: :media_id

    execute "ALTER TABLE updates RENAME CONSTRAINT updates_media_uuid_fkey TO updates_media_id_fkey;"

    execute "ALTER TABLE media_subscriptions drop constraint media_subscriptions_media_id_fkey;"
    execute "ALTER TABLE media_subscriptions drop column media_id;"
    rename table(:media_subscriptions), :media_uuid, to: :media_id

    execute "ALTER TABLE media_subscriptions RENAME CONSTRAINT media_subscriptions_media_uuid_fkey TO media_subscriptions_media_id_fkey;"

    execute "ALTER TABLE notifications drop constraint notifications_media_id_fkey;"
    execute "ALTER TABLE notifications drop column media_id;"
    rename table(:notifications), :media_uuid, to: :media_id

    execute "ALTER TABLE notifications RENAME CONSTRAINT notifications_media_uuid_fkey TO notifications_media_id_fkey;"

    execute "ALTER TABLE media_versions drop constraint media_versions_media_id_fkey;"
    execute "ALTER TABLE media_versions drop column media_id;"
    rename table(:media_versions), :media_uuid, to: :media_id

    execute "ALTER TABLE media_versions RENAME CONSTRAINT media_versions_media_uuid_fkey TO media_versions_media_id_fkey;"

    # Drop the old primary key
    execute "ALTER TABLE media drop constraint media_pkey;"

    # Rename the old id column to integer_id, and the uuid column to id
    rename table("media"), :id, to: :deprecated_integer_id
    rename table("media"), :uuid, to: :id

    # Set the new primary key
    execute "ALTER TABLE media ADD PRIMARY KEY (id);"
  end

  def down do
    # Irreversible
  end
end
