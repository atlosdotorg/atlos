defmodule Platform.Repo.Migrations.AddDeletedFieldToMedia do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :deleted, :boolean, default: false
    end
  end
end
