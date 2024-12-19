defmodule Platform.Repo.Migrations.AddSearchableText do
  use Ecto.Migration

  def change do
    # Drop the 'searchable' column from the 'media' table
    execute "ALTER TABLE media DROP COLUMN searchable;", ""
    execute "ALTER TABLE media DROP COLUMN IF EXISTS searchable_text;", ""

    # Add helper function for array to string conversion that's immutable
    execute """
            CREATE OR REPLACE FUNCTION imm_array_to_string(arr text[], delim text, nullstr text DEFAULT '')
            RETURNS text
            LANGUAGE sql
            IMMUTABLE PARALLEL SAFE STRICT
            AS $$
              SELECT array_to_string(arr, delim, nullstr);
            $$;
            """,
            ""

    # Add the 'searchable_text' column to the media table
    execute """
              ALTER TABLE media
              ADD COLUMN searchable_text text
              GENERATED ALWAYS AS (
                COALESCE(slug, '') || ' ' ||
                COALESCE(attr_description, '') || ' ' ||
                COALESCE(attr_more_info, '') || ' ' ||
                COALESCE(attr_general_location, '') || ' ' ||
                COALESCE(attr_status, '') || ' ' ||
                COALESCE(imm_array_to_string(attr_restrictions, ' ', ''), '') || ' ' ||
                COALESCE(imm_array_to_string(attr_sensitive, ' ', ''), '') || ' ' ||
                COALESCE(project_attributes::text, '') || ' ' ||
                COALESCE(auto_metadata::text, '')
              ) STORED;
            """,
            "ALTER TABLE media DROP COLUMN searchable_text"

    # Add the 'searchable' column to the 'media' table
    execute """
              ALTER TABLE media
              ADD COLUMN searchable tsvector
              GENERATED ALWAYS AS (
                setweight(to_tsvector('simple', coalesce(slug, '')), 'A') ||
                setweight(to_tsvector('simple', coalesce(attr_description, '')), 'A') ||
                setweight(to_tsvector('simple', coalesce(attr_more_info, '')), 'B') ||
                setweight(jsonb_to_tsvector('simple', coalesce(project_attributes, '{}'), '"string"'), 'B') ||
                setweight(to_tsvector('simple', coalesce(attr_general_location, '')), 'C') ||
                setweight(to_tsvector('simple', imm_array_to_string(attr_restrictions, ' ', ' ')), 'C') ||
                setweight(to_tsvector('simple', imm_array_to_string(attr_sensitive, ' ', ' ')), 'C') ||
                setweight(to_tsvector('simple', coalesce(attr_status, '')), 'C') ||
                setweight(jsonb_to_tsvector('simple', coalesce(auto_metadata, '{}'), '"string"'), 'D')
              ) STORED;
            """,
            "ALTER TABLE media DROP COLUMN searchable"

    # Add an index to the 'media' table on searchable
    create index(:media, ["searchable"], using: "GIN")

    # Clean up functions in the rollback
    execute "DROP FUNCTION IF EXISTS imm_array_to_string(text[], text, text);", ""
  end
end
