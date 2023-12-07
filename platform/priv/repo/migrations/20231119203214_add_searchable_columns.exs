defmodule Platform.Repo.Migrations.AddSearchableColumns do
  use Ecto.Migration

  def change do
    # Goal: add a usable searchable column to mediaversions, users, projects, media, and updates (media is already searchable)
    # First drop "searchable", then re-add searchable column to media_versions
    execute "ALTER TABLE media_versions DROP COLUMN searchable", ""

    execute """
              ALTER TABLE media_versions
              ADD COLUMN searchable tsvector
              GENERATED ALWAYS AS (
                setweight(to_tsvector('simple', coalesce(source_url, '')), 'A') ||
                setweight(jsonb_to_tsvector('simple', coalesce(metadata, '{}'), '"string"'), 'B')
              ) STORED
            """,
            ""

    create index(:media_versions, ["searchable"], using: "GIN")

    execute "ALTER TABLE users DROP COLUMN searchable", ""

    execute """
              ALTER TABLE users
              ADD COLUMN searchable tsvector
              GENERATED ALWAYS AS (
                setweight(to_tsvector('simple', coalesce(username, '')), 'A') ||
                setweight(to_tsvector('simple', coalesce(bio, '')), 'B') ||
                setweight(to_tsvector('simple', coalesce(flair, '')), 'B')
              ) STORED
            """,
            ""

    create index(:users, ["searchable"], using: "GIN")

    execute """
              ALTER TABLE projects
              ADD COLUMN searchable tsvector
              GENERATED ALWAYS AS (
                setweight(to_tsvector('simple', coalesce(code, '')), 'A') ||
                setweight(to_tsvector('simple', coalesce(name, '')), 'A') ||
                setweight(to_tsvector('simple', coalesce(description, '')), 'B')
              ) STORED
            """,
            "ALTER TABLE projects DROP COLUMN searchable"

    create index(:projects, ["searchable"], using: "GIN")

    execute "ALTER TABLE media DROP COLUMN searchable", ""

    execute """
              ALTER TABLE media
              ADD COLUMN searchable tsvector
              GENERATED ALWAYS AS (
                setweight(to_tsvector('simple', coalesce(slug, '')), 'A') ||
                setweight(to_tsvector('simple', coalesce(attr_description, '')), 'A') ||
                setweight(to_tsvector('simple', coalesce(attr_more_info, '')), 'B') ||
                setweight(to_tsvector('simple', coalesce(attr_general_location, '')), 'C') ||
                setweight(to_tsvector('simple', imm_array_to_string(attr_restrictions, ' ', ' ')), 'C') ||
                setweight(to_tsvector('simple', imm_array_to_string(attr_sensitive, ' ', ' ')), 'C') ||
                setweight(to_tsvector('simple', coalesce(attr_status, '')), 'C') ||
                setweight(jsonb_to_tsvector('simple', coalesce(auto_metadata, '{}'), '"string"'), 'D')
              ) STORED
            """,
            ""

    create index(:media, ["searchable"], using: "GIN")

    execute "ALTER TABLE updates DROP COLUMN searchable", ""

    execute """
              ALTER TABLE updates
              ADD COLUMN searchable tsvector
              GENERATED ALWAYS AS (
                setweight(to_tsvector('simple', coalesce(explanation, '')), 'A') ||
                setweight(jsonb_to_tsvector('simple', coalesce(new_value::jsonb, '{}'), '"string"'), 'B') ||
                setweight(jsonb_to_tsvector('simple', coalesce(old_value::jsonb, '{}'), '"string"'), 'C') ||
                setweight(to_tsvector('simple', coalesce(type, '')), 'C') ||
                setweight(to_tsvector('simple', coalesce(search_metadata, '')), 'C')
              ) STORED
            """,
            ""

    create index(:updates, ["searchable"], using: "GIN")
  end
end
