defmodule Platform.Repo.Migrations.AddRecoverycodeToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :recovery_codes, {:array, :string}, default: []
      add :used_recovery_codes, {:array, :string}, default: []
    end
  end
end
