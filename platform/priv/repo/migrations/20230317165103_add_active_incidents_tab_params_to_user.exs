defmodule Platform.Repo.Migrations.AddActiveIncidentsTabParamsToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:active_incidents_tab_params, :map)
      add(:active_incidents_tab_params_time, :naive_datetime)
    end
  end
end
