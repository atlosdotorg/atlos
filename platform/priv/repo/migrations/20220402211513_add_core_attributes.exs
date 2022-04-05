defmodule Platform.Repo.Migrations.AddCoreAttributes do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :attr_geolocation, :geometry
      add :attr_environment, :string
      add :attr_weather, {:array, :string}
      add :attr_recorded_by, :string
      add :attr_more_info, :text
      add :attr_civilian_impact, {:array, :string}
      add :attr_event, {:array, :string}
      add :attr_casualty, {:array, :string}
      add :attr_military_infrastructure, {:array, :string}
      add :attr_weapon, {:array, :string}
      add :attr_time_recorded, :time
      add :attr_date_recorded, :date
    end
  end
end
