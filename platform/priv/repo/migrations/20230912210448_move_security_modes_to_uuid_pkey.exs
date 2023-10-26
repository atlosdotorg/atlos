defmodule Platform.Repo.Migrations.MoveSecurityModesToUuidPkey do
  use Ecto.Migration

  def up do
    # Create a new UUID column and set it as the primary key
    alter table("security_modes") do
      add :uuid, :binary_id, default: fragment("gen_random_uuid()"), null: false
    end

    # Add a unique constraint on the new uuid column
    create unique_index("security_modes", [:uuid])

    # Drop the old primary key
    execute "ALTER TABLE security_modes drop constraint security_modes_pkey;"

    # Rename the old id column to integer_id, and the uuid column to id
    rename table("security_modes"), :id, to: :deprecated_integer_id
    rename table("security_modes"), :uuid, to: :id

    # Set the new primary key
    execute "ALTER TABLE security_modes ADD PRIMARY KEY (id);"
  end

  def down do
    # Irreversible
  end
end
