defmodule Platform.Repo.Migrations.AddColorsToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :color, :string, default: "#808080"
    end
  end
end
