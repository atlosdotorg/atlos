defmodule Platform.Repo.Migrations.AddMediaVersionsInsertedAtIndex do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:media_versions, [:inserted_at], concurrently: true)
  end
end
