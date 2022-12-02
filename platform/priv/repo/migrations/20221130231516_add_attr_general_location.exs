defmodule Platform.Repo.Migrations.AddAttrGeneralLocation do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :attr_general_location, :string
    end
  end
end
