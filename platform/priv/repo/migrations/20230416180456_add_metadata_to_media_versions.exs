defmodule Platform.Repo.Migrations.AddMetadataToMediaVersions do
  use Ecto.Migration

  def change do
    alter table(:media_versions) do
      add(:metadata, :map)
    end
  end
end
