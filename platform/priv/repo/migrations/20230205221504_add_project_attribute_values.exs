defmodule Platform.Repo.Migrations.AddProjectAttributeValues do
  use Ecto.Migration

  def change do
    create table(:project_attribute_values, primary_key: false) do
      add(:id, :binary_id, primary_key: true, autogenerate: true)

      add(
        :project_attribute_id,
        references(:project_attributes, type: :binary_id, on_delete: :nilify_all)
      )

      add(:media_id, references(:media, on_delete: :delete_all))
      add(:value, :map)

      timestamps()
    end

    create(unique_index(:project_attribute_values, [:project_attribute_id, :media_id]))
    create(index(:project_attribute_values, [:project_attribute_id]))
    create(index(:project_attribute_values, [:media_id]))
  end
end
