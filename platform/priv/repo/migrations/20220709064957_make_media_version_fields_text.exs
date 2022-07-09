defmodule Platform.Repo.Migrations.MakeMediaVersionFieldsText do
  use Ecto.Migration

  def change do
    alter table(:media_versions) do
      modify :file_location, :text
      modify :source_url, :text
    end
  end
end
