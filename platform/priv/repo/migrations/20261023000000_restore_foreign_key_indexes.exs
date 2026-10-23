defmodule Platform.Repo.Migrations.RestoreForeignKeyIndexes do
  use Ecto.Migration

  # The UUID primary key migrations (2023-09) recreated these foreign key columns but not their
  # indexes, so every preload of updates/versions and every per-user feed was a sequential scan.
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create_if_not_exists index(:updates, [:media_id, :inserted_at], concurrently: true)
    create_if_not_exists index(:updates, [:user_id, :inserted_at], concurrently: true)
    create_if_not_exists index(:media_versions, [:media_id], concurrently: true)
    create_if_not_exists index(:media, [:project_id, :inserted_at], concurrently: true)
    create_if_not_exists index(:notifications, [:user_id, :media_id], concurrently: true)
    create_if_not_exists index(:notifications, [:media_id], concurrently: true)
    create_if_not_exists index(:media_subscriptions, [:media_id], concurrently: true)
  end
end
