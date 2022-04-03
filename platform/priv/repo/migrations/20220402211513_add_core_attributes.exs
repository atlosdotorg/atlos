defmodule Platform.Repo.Migrations.AddCoreAttributes do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :attr_geolocation, :geometry
      add :attr_environment, :string
    end
  end
end
