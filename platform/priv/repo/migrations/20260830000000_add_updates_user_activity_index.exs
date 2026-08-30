defmodule Platform.Repo.Migrations.AddUpdatesUserActivityIndex do
  use Ecto.Migration

  # Supports the per-user activity rollups behind the admin usage dashboard
  # (updates counted per user within a time window).
  def change do
    create index(:updates, [:user_id, :inserted_at])
  end
end
