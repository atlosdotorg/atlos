defmodule Platform.Repo.Migrations.AddSubscriptions do
  use Ecto.Migration

  def change do
    create table(:media_subscriptions) do
      add :media_id, references(:media)
      add :user_id, references(:users)

      timestamps()
    end

    create unique_index(:media_subscriptions, [:media_id, :user_id])
  end
end
