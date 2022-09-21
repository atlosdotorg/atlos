defmodule Platform.Repo.Migrations.CreateSecurityModes do
  use Ecto.Migration

  def change do
    create table(:security_modes) do
      add :description, :string
      add :mode, :string
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create index(:security_modes, [:user_id])
    create index(:security_modes, ["inserted_at DESC"])
  end
end
