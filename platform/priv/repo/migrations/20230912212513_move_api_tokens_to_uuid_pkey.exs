defmodule Platform.Repo.Migrations.MoveApiTokensToUuidPkey do
  use Ecto.Migration

  def up do
    # Create a new UUID column and set it as the primary key
    alter table("api_tokens") do
      add :uuid, :binary_id, default: fragment("gen_random_uuid()"), null: false
    end

    # Add a unique constraint on the new uuid column
    create unique_index("api_tokens", [:uuid])

    # Drop the old primary key
    execute "ALTER TABLE api_tokens drop constraint api_tokens_pkey;"

    # Rename the old id column to integer_id, and the uuid column to id
    rename table("api_tokens"), :id, to: :deprecated_integer_id
    rename table("api_tokens"), :uuid, to: :id

    # Set the new primary key
    execute "ALTER TABLE api_tokens ADD PRIMARY KEY (id);"
  end

  def down do
    # Irreversible
  end
end
