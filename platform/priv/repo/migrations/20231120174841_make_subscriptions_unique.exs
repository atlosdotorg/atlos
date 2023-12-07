defmodule Platform.Repo.Migrations.MakeSubscriptionsUnique do
  use Ecto.Migration

  def change do
    # Delete all non-unique media_subscriptions
    execute """
    WITH CTE AS (
        SELECT
            id,
            ROW_NUMBER() OVER (PARTITION BY user_id, media_id ORDER BY inserted_at) as rn
        FROM
        media_subscriptions
    )
    DELETE FROM
      media_subscriptions
    WHERE
      id IN (SELECT id FROM CTE WHERE rn > 1)
    """

    create unique_index(:media_subscriptions, [:user_id, :media_id])
  end
end
