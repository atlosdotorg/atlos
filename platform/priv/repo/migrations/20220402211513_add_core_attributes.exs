defmodule Platform.Repo.Migrations.AddCoreAttributes do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :attr_geolocation, :geometry
      add :attr_environment, :string
      add :attr_weather, {:array, :string}
      add :attr_recorded_by, :string
    end
  end
end
