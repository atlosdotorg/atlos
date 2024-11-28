defmodule Platform.Repo.Migrations.MoveDescriptionToTextField do
  use Ecto.Migration

  def change do
    # Drop the 'searchable' column from the 'media' table
    execute "ALTER TABLE media DROP COLUMN searchable;"

    alter table(:media) do
      modify :attr_description, :text
    end

    # Add the 'searchable' column to the 'media' table
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

    # Add an index to the 'media' table on searchable
    create index(:media, ["searchable"], using: "GIN")
  end
end
