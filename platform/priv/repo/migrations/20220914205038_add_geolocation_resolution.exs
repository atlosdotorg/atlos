defmodule Platform.Repo.Migrations.AddGeolocationResolution do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :attr_geolocation_resolution, :string
    end
  end
end
