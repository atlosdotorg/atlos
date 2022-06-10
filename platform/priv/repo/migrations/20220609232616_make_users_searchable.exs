defmodule Platform.Repo.Migrations.MakeUsersSearchable do
  use Ecto.Migration

  def change do
    execute """
            ALTER TABLE users
            ADD COLUMN searchable tsvector
            GENERATED ALWAYS AS (
              to_tsvector('english',
                imm_array_to_string(
                  coalesce(email, '') || ARRAY[]::text[] ||
                  coalesce(username, '') || ARRAY[]::text[] ||
                  coalesce(roles, '{}') || ARRAY[]::text[] ||
                  coalesce(restrictions, '{}') || ARRAY[]::text[] ||
                  coalesce(bio, '') || ARRAY[]::text[] ||
                  coalesce(flair, '{}') || ARRAY[]::text[] ||
                  coalesce(admin_notes, '{}'),
                  ' ', ''
                )
              )
            ) STORED
            """
            |> String.replace("\n", " "),
            "ALTER TABLE users DROP COLUMN searchable"

    create index(:users, ["searchable"],
             name: :users_searchable_index,
             using: "GIN"
           )

    create index(:users, [:inserted_at])
    create index(:users, [:updated_at])
  end
end
