defmodule Platform.Repo.Migrations.AddSearchableToMediaVersions do
  use Ecto.Migration

  def change do
    execute """
            ALTER TABLE media_versions
            ADD COLUMN searchable tsvector
            GENERATED ALWAYS AS (
              to_tsvector('english',
                imm_array_to_string(
                  coalesce(source_url, '') || ARRAY[]::text[] ||
                  coalesce(hashes::text, ''),
                  ' ', ''
                )
              )
            ) STORED
            """
            |> String.replace("\n", " "),
            "ALTER TABLE media_versions DROP COLUMN searchable"

    create index(:media_versions, ["searchable"],
             name: "media_version_search_index",
             using: "GIN"
           )
  end
end
