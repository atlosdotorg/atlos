defmodule Platform.Repo.Migrations.MoveMediaSubscriptionsToUuidPkey do
  use Ecto.Migration

  def up do
    # Create a new UUID column and set it as the primary key
    alter table("media_subscriptions") do
      add :uuid, :binary_id, default: fragment("gen_random_uuid()"), null: false
    end

    # Add a unique constraint on the new uuid column
    create unique_index("media_subscriptions", [:uuid])

    # Drop the old primary key
    execute "ALTER TABLE media_subscriptions drop constraint media_subscriptions_pkey;"

    # Rename the old id column to integer_id, and the uuid column to id
    rename table("media_subscriptions"), :id, to: :deprecated_integer_id
    rename table("media_subscriptions"), :uuid, to: :id

    # Set the new primary key
    execute "ALTER TABLE media_subscriptions ADD PRIMARY KEY (id);"
  end

  def down do
    # Irreversible
  end
end
