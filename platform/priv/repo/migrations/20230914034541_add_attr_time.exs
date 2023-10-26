defmodule Platform.Repo.Migrations.AddAttrTime do
  use Ecto.Migration

  def change do
    alter table(:media) do
      # Time is a time; no day or timezone information
      add :attr_time, :time, null: true
    end
  end
end
