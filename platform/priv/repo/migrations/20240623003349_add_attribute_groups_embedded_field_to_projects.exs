defmodule Platform.Repo.Migrations.AddAttributeGroupsEmbeddedFieldToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :attribute_groups, :map
    end
  end
end
