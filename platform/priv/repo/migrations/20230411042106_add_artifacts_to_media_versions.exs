defmodule Platform.Repo.Migrations.AddArtifactsToMediaVersions do
  use Ecto.Migration

  def change do
    alter table(:media_versions) do
      add(:artifacts, :map, default: nil)
    end
  end
end
