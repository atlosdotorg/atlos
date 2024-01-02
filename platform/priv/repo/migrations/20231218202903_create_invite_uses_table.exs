defmodule Platform.Repo.Migrations.CreateInviteUsesTable do
  use Ecto.Migration

  def change do
    create table(:invite_uses, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :invite_id, references(:invites, type: :binary_id), null: false
      add :user_id, references(:users, type: :binary_id), null: false
      timestamps()
    end

    create index(:invite_uses, [:invite_id])
    create index(:invite_uses, [:user_id])
    create unique_index(:invite_uses, [:invite_id, :user_id])

    # Create an invite use for each user who has used an invite. Each user currently has
    # an "invite_id" field; this is the invite that the user used to register. We want
    # to create an invite use for each user who has an invite_id, with the timestamps
    # set to when their record was created.
    execute """
            INSERT INTO invite_uses (id, invite_id, user_id, inserted_at, updated_at)
            SELECT gen_random_uuid(), invite_id, id, inserted_at, inserted_at
            FROM users
            WHERE invite_id IS NOT NULL
            """,
            ""
  end
end
