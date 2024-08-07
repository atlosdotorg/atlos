defmodule Platform.Repo.Migrations.AddAutoMetadataToMedia do
  use Ecto.Migration

  def change do
    execute "ALTER TABLE media DROP COLUMN searchable",
            """
            ALTER TABLE media
            ADD COLUMN searchable tsvector
            GENERATED ALWAYS AS (
              to_tsvector('english',
                imm_array_to_string(
                  coalesce(slug, '') || ARRAY[]::text[] ||

                  coalesce(attr_description, '') || ARRAY[]::text[] ||
                  coalesce(attr_more_info, '') || ARRAY[]::text[] ||
                  coalesce(attr_type, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_impact, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_equipment, '{}') || ARRAY[]::text[] ||

                  coalesce(attr_restrictions, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_sensitive, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_status, '') || ARRAY[]::text[] ||
                  coalesce(attr_tags, '{}'),
                  ' ', ''
                )
              )
            ) STORED
            """
            |> String.replace("\n", " ")

    alter table(:media) do
      add :auto_metadata, :map, default: %{}
    end

    execute """
            ALTER TABLE media
            ADD COLUMN searchable tsvector
            GENERATED ALWAYS AS (
              to_tsvector('english',
                imm_array_to_string(
                  coalesce(slug, '') || ARRAY[]::text[] ||

                  coalesce(attr_description, '') || ARRAY[]::text[] ||
                  coalesce(attr_more_info, '') || ARRAY[]::text[] ||
                  coalesce(attr_type, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_impact, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_equipment, '{}') || ARRAY[]::text[] ||

                  coalesce(attr_restrictions, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_sensitive, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_status, '') || ARRAY[]::text[] ||
                  coalesce(attr_tags, '{}'),
                  ' ', ''
                )
              ) || to_tsvector('english', auto_metadata)
            ) STORED
            """
            |> String.replace("\n", " "),
            "ALTER TABLE media DROP COLUMN searchable"
  end
end
