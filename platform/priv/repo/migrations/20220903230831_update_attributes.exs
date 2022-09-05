defmodule Platform.Repo.Migrations.UpdateAttributes do
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
                  coalesce(attr_time_of_day, '') || ARRAY[]::text[] ||
                  coalesce(attr_environment, '') || ARRAY[]::text[] ||
                  coalesce(attr_weather, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_camera_system, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_more_info, '') || ARRAY[]::text[] ||
                  coalesce(attr_civilian_impact, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_event, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_casualty, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_military_infrastructure, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_tags, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_weapon, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_status, '') || ARRAY[]::text[] ||

                  coalesce(attr_sensitive, '{}') || ARRAY[]::text[] ||
                  coalesce(attr_restrictions, '{}'),
                  ' ', ''
                )
              )
            ) STORED
            """
            |> String.replace("\n", " ")

    alter table(:media) do
      add :attr_type, {:array, :string}
      add :attr_impact, {:array, :string}
      add :attr_equipment, {:array, :string}
    end

    rename table(:media), :attr_date_recorded, to: :attr_date
    rename table(:media), :description, to: :attr_description

    create index(:media, [:attr_type], using: "GIN")
    create index(:media, [:attr_impact], using: "GIN")
    create index(:media, [:attr_equipment], using: "GIN")

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
              )
            ) STORED
            """
            |> String.replace("\n", " "),
            "ALTER TABLE media DROP COLUMN searchable"
  end
end
