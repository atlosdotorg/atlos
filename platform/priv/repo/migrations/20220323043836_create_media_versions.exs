defmodule Platform.Repo.Migrations.CreateMediaVersions do
  use Ecto.Migration

  def change do
    create table(:media_versions) do
      add :type, :string
      add :perceptual_hash, :binary
      add :source_url, :string
      add :file_size, :integer
      add :file_location, :string
      add :media_id, references(:media, on_delete: :nothing)

      timestamps()
    end

    create index(:media_versions, [:media_id])
  end
end
