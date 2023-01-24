defmodule Platform.Repo.Migrations.AddDescriptionToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :description, :string, default: ""
    end
  end
end
