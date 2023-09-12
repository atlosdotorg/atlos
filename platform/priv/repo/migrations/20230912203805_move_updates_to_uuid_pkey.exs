defmodule Platform.Repo.Migrations.MoveUpdatesToUuidPkey do
  use Ecto.Migration

  def up do
    # Create a new UUID column and set it as the primary key
    alter table("updates") do
      add :uuid, :binary_id, default: fragment("gen_random_uuid()"), null: false
    end

    # Add a unique constraint on the new uuid column
    create unique_index("updates", [:uuid])

    # Create new UUID columns for all constraints
    alter table(:notifications) do
      add :update_uuid, references("updates", type: :binary_id, column: :uuid), null: true
    end

    # Insert the UUIDs into the constraint columns
    execute "update notifications set update_uuid = updates.uuid from updates where notifications.update_id = updates.id",
            []

    # Drop the old constraint columns
    execute "ALTER TABLE notifications drop constraint notifications_update_id_fkey;"
    execute "ALTER TABLE notifications drop column update_id;"
    rename table(:notifications), :update_uuid, to: :update_id

    execute "ALTER TABLE notifications RENAME CONSTRAINT notifications_update_uuid_fkey TO notifications_update_id_fkey;"

    # Drop the old primary key
    execute "ALTER TABLE updates drop constraint updates_pkey;"

    # Rename the old id column to integer_id, and the uuid column to id
    rename table("updates"), :id, to: :deprecated_integer_id
    rename table("updates"), :uuid, to: :id

    # Set the new primary key
    execute "ALTER TABLE updates ADD PRIMARY KEY (id);"
  end

  def down do
    # Irreversible
  end
end
