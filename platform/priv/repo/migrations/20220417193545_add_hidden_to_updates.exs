defmodule Platform.Repo.Migrations.AddHiddenToUpdates do
  use Ecto.Migration

  def change do
    alter table(:updates) do
      add :hidden, :boolean, default: false
    end
  end
end
