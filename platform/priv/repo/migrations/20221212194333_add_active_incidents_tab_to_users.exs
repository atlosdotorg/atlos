defmodule Platform.Repo.Migrations.AddActiveIncidentsTabToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :active_incidents_tab, :string, default: "map"
    end
  end
end
