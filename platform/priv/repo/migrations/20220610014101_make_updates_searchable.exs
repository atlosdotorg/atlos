defmodule Platform.Repo.Migrations.MakeUpdatesSearchable do
  use Ecto.Migration

  def change do
    alter table(:updates) do
      add :search_metadata, :string, default: ""
    end

    execute """
            ALTER TABLE updates
            ADD COLUMN searchable tsvector
            GENERATED ALWAYS AS (
              to_tsvector('english',
                imm_array_to_string(
                  coalesce(explanation, '') || ARRAY[]::text[] ||
                  coalesce(type, '') || ARRAY[]::text[] ||
                  coalesce(modified_attribute, '') || ARRAY[]::text[] ||
                  coalesce(new_value, '') || ARRAY[]::text[] ||
                  coalesce(old_value, '') || ARRAY[]::text[] ||
                  coalesce(search_metadata, ''),
                  ' ', ''
                )
              )
            ) STORED
            """
            |> String.replace("\n", " "),
            "ALTER TABLE updates DROP COLUMN searchable"

    create index(:updates, ["searchable"],
             name: :updates_searchable_index,
             using: "GIN"
           )

    create index(:updates, [:inserted_at])
    create index(:updates, [:updated_at])
  end
end
