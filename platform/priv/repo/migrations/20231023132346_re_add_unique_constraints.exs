defmodule Platform.Repo.Migrations.ReAddUniqueConstraints do
  use Ecto.Migration

  def change do
    # Delete all non-unique project_memberships
    execute """
    WITH CTE AS (
        SELECT
            id,
            ROW_NUMBER() OVER (PARTITION BY user_id, project_id ORDER BY inserted_at) as rn
        FROM
            project_memberships
    )
    DELETE FROM
        project_memberships
    WHERE
      id IN (SELECT id FROM CTE WHERE rn > 1)
    """

    create unique_index(:project_memberships, [:user_id, :project_id])
    create unique_index(:media_versions, [:scoped_id, :media_id])
  end
end
