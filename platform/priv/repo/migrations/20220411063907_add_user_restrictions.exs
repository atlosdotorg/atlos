defmodule Platform.Repo.Migrations.AddUserRestrictions do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :restrictions, {:array, :string}
    end
  end
end
