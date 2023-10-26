defmodule Platform.Repo.Migrations.MoveUsersTokensToUuidPkey do
  use Ecto.Migration

  def up do
    # Create a new UUID column and set it as the primary key
    alter table("users_tokens") do
      add :uuid, :binary_id, default: fragment("gen_random_uuid()"), null: false
    end

    # Add a unique constraint on the new uuid column
    create unique_index("users_tokens", [:uuid])

    # Drop the old primary key
    execute "ALTER TABLE users_tokens drop constraint users_tokens_pkey;"

    # Rename the old id column to integer_id, and the uuid column to id
    rename table("users_tokens"), :id, to: :deprecated_integer_id
    rename table("users_tokens"), :uuid, to: :id

    # Set the new primary key
    execute "ALTER TABLE users_tokens ADD PRIMARY KEY (id);"
  end

  def down do
    # Irreversible
  end
end
