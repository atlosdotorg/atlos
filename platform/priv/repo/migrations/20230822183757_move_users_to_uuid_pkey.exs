defmodule Platform.Repo.Migrations.MoveUsersToUuidPkey do
  use Ecto.Migration

  def up do
    # Create a new UUID column and set it as the primary key
    alter table("users") do
      add :uuid, :binary_id, default: fragment("gen_random_uuid()"), null: false
    end

    # Add a unique constraint on the new uuid column
    create unique_index("users", [:uuid])

    # Create new UUID columns for all constraints
    alter table(:users_tokens) do
      add :user_uuid, references("users", type: :binary_id, column: :uuid), null: true
    end
    alter table(:updates) do
      add :user_uuid, references("users", type: :binary_id, column: :uuid), null: true
    end
    alter table(:media_subscriptions) do
      add :user_uuid, references("users", type: :binary_id, column: :uuid), null: true
    end
    alter table(:invites) do
      add :owner_uuid, references("users", type: :binary_id, column: :uuid), null: true
    end
    alter table(:security_modes) do
      add :user_uuid, references("users", type: :binary_id, column: :uuid), null: true
    end
    alter table(:notifications) do
      add :user_uuid, references("users", type: :binary_id, column: :uuid), null: true
    end
    alter table(:project_memberships) do
      add :user_uuid, references("users", type: :binary_id, column: :uuid), null: true
    end

    # Insert the UUIDs into the constraint columns
    execute "update users_tokens tokens set user_uuid = users.uuid from users where tokens.user_id = users.id", []
    execute "update updates set user_uuid = users.uuid from users where updates.user_id = users.id", []
    execute "update media_subscriptions set user_uuid = users.uuid from users where media_subscriptions.user_id = users.id", []
    execute "update invites set owner_uuid = users.uuid from users where invites.owner_id = users.id", []
    execute "update security_modes set user_uuid = users.uuid from users where security_modes.user_id = users.id", []
    execute "update notifications set user_uuid = users.uuid from users where notifications.user_id = users.id", []
    execute "update project_memberships set user_uuid = users.uuid from users where project_memberships.user_id = users.id", []

    # Drop the old constraint columns
    execute "ALTER TABLE users_tokens drop constraint users_tokens_user_id_fkey;"
    execute "ALTER TABLE users_tokens drop column user_id;"
    rename table(:users_tokens), :user_uuid, to: :user_id
    execute "ALTER TABLE users_tokens RENAME CONSTRAINT users_tokens_user_uuid_fkey TO users_tokens_user_id_fkey;"

    execute "ALTER TABLE updates drop constraint updates_user_id_fkey;"
    execute "ALTER TABLE updates drop column user_id;"
    rename table(:updates), :user_uuid, to: :user_id
    execute "ALTER TABLE updates RENAME CONSTRAINT updates_user_uuid_fkey TO updates_user_id_fkey;"

    execute "ALTER TABLE media_subscriptions drop constraint media_subscriptions_user_id_fkey;"
    execute "ALTER TABLE media_subscriptions drop column user_id;"
    rename table(:media_subscriptions), :user_uuid, to: :user_id
    execute "ALTER TABLE media_subscriptions RENAME CONSTRAINT media_subscriptions_user_uuid_fkey TO media_subscriptions_user_id_fkey;"

    execute "ALTER TABLE invites drop constraint invites_owner_id_fkey;"
    execute "ALTER TABLE invites drop column owner_id;"
    rename table(:invites), :owner_uuid, to: :owner_id
    execute "ALTER TABLE invites RENAME CONSTRAINT invites_owner_uuid_fkey TO invites_user_id_fkey;"

    execute "ALTER TABLE security_modes drop constraint security_modes_user_id_fkey;"
    execute "ALTER TABLE security_modes drop column user_id;"
    rename table(:security_modes), :user_uuid, to: :user_id
    execute "ALTER TABLE security_modes RENAME CONSTRAINT security_modes_user_uuid_fkey TO security_modes_user_id_fkey;"

    execute "ALTER TABLE notifications drop constraint notifications_user_id_fkey;"
    execute "ALTER TABLE notifications drop column user_id;"
    rename table(:notifications), :user_uuid, to: :user_id
    execute "ALTER TABLE notifications RENAME CONSTRAINT notifications_user_uuid_fkey TO notifications_user_id_fkey;"

    execute "ALTER TABLE project_memberships drop constraint project_memberships_user_id_fkey;"
    execute "ALTER TABLE project_memberships drop column user_id;"
    rename table(:project_memberships), :user_uuid, to: :user_id
    execute "ALTER TABLE project_memberships RENAME CONSTRAINT project_memberships_user_uuid_fkey TO project_memberships_user_id_fkey;"

    # Drop the old primary key
    execute "ALTER TABLE users drop constraint users_pkey;"

    # Rename the old id column to integer_id, and the uuid column to id
    rename table("users"), :id, to: :deprecated_integer_id
    rename table("users"), :uuid, to: :id

    # Set the new primary key
    execute "ALTER TABLE users ADD PRIMARY KEY (id);"
  end

  def down do
    # Irreversible
  end
end
