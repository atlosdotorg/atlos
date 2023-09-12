defmodule Platform.Repo.Migrations.MoveInvitesToUuidPkey do
  use Ecto.Migration

  def up do
    # Create a new UUID column and set it as the primary key
    alter table("invites") do
      add :uuid, :binary_id, default: fragment("gen_random_uuid()"), null: false
    end

    # Add a unique constraint on the new uuid column
    create unique_index("invites", [:uuid])

    # Create new UUID columns for all constraints
    alter table(:users) do
      add :invite_uuid, references("invites", type: :binary_id, column: :uuid), null: true
    end

    # Insert the UUIDs into the constraint columns
    execute "update users set invite_uuid = invites.uuid from invites where users.invite_id = invites.id", []

    # Drop the old constraint columns
    execute "ALTER TABLE users drop constraint users_invite_id_fkey;"
    execute "ALTER TABLE users drop column invite_id;"
    rename table(:users), :invite_uuid, to: :invite_id
    execute "ALTER TABLE users RENAME CONSTRAINT users_invite_uuid_fkey TO users_invite_id_fkey;"

    # Drop the old primary key
    execute "ALTER TABLE invites drop constraint invites_pkey;"

    # Rename the old id column to integer_id, and the uuid column to id
    rename table("invites"), :id, to: :deprecated_integer_id
    rename table("invites"), :uuid, to: :id

    # Set the new primary key
    execute "ALTER TABLE invites ADD PRIMARY KEY (id);"
  end

  def down do
    # Irreversible
  end
end
