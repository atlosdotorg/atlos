defmodule Platform.Repo.Migrations.AddMediaAttributes do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :attr_sensitive, {:array, :string}
    end

    create index(:media, [:attr_sensitive], name: "attr_sensitive_index", using: "GIN")
  end
end
