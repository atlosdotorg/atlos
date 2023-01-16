defmodule Platform.Repo.Migrations.AddCustomAttributesIndex do
  use Ecto.Migration

  def up do
    execute("CREATE INDEX project_attributes_index ON media USING GIN(project_attributes)")
  end

  def down do
    execute("DROP INDEX project_attributes_index")
  end
end
