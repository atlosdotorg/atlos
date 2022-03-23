defmodule Platform.Repo.Migrations.CreateMedia do
  use Ecto.Migration

  def change do
    create table(:media) do
      add :description, :string
      add :slug, :string

      timestamps()
    end

    create unique_index(:media, [:slug])
  end
end
