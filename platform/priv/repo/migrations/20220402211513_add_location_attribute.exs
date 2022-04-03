defmodule Platform.Repo.Migrations.AddLocationAttribute do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :attr_geolocation, :geometry
    end
  end
end
