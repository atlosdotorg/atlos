defmodule Platform.Repo.Migrations.AddSafetyAttributes do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :attr_restrictions, {:array, :string}
    end
  end
end
