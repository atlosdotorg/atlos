defmodule Platform.Repo.Migrations.MakeInternetArchiveOptional do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :should_sync_with_internet_archive, :boolean, default: false
    end
  end
end
