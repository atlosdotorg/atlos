defmodule Platform.Repo.Migrations.AddActiveFlagToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :active, :boolean, default: true
    end
  end
end
