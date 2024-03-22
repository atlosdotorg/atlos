defmodule Platform.Repo.Migrations.AddNotificationsSearchableColumn do
  use Ecto.Migration

  def change do
    execute """
              ALTER TABLE notifications
              ADD COLUMN searchable tsvector
              GENERATED ALWAYS AS (
                setweight(to_tsvector('simple', coalesce(content, '')), 'A')
              ) STORED
            """,
            ""

    create index(:notifications, ["searchable"], using: "GIN")
  end
end
