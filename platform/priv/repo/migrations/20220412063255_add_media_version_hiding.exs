defmodule Platform.Repo.Migrations.AddMediaVersionHiding do
  use Ecto.Migration

  def change do
    alter table(:media_versions) do
      add :hidden, :boolean, default: false
    end
  end
end
