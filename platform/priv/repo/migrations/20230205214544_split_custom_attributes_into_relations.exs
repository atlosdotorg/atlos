defmodule Platform.Repo.Migrations.SplitCustomAttributesIntoRelations do
  use Ecto.Migration

  def change do
    create table(:project_attributes, primary_key: false) do
      add(:id, :binary_id, primary_key: true, autogenerate: true)
      add(:name, :string)
      add(:type, :string)
      add(:options, {:array, :string}, default: [])
      add(:project_id, references(:projects, type: :binary_id, on_delete: :delete_all))

      timestamps()
    end

    create(index(:project_attributes, [:project_id]))
  end
end
