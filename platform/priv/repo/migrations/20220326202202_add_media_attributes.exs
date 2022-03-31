defmodule Platform.Repo.Migrations.AddMediaAttributes do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :attr_sensitive, {:array, :string}
      add :attr_time_of_day, :string
    end

    create index(:media, [:attr_sensitive], name: "attr_sensitive_index", using: "GIN")
    create index(:media, [:attr_time_of_day], name: "attr_time_of_day")
  end
end
