defmodule Platform.Repo.Migrations.MoveDescriptionToTextField do
  use Ecto.Migration

  def change do
    alter table(:media) do
      modify :attr_description, :text
    end
  end
end
