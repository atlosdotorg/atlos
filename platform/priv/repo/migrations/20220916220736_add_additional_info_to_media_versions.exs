defmodule Platform.Repo.Migrations.AddAdditionalInfoToMediaVersions do
  use Ecto.Migration

  def change do
    alter table(:media_versions) do
      add :hashes, :map, default: %{}
    end
  end
end
