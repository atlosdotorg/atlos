defmodule Platform.Repo.Migrations.CreateInvites do
  use Ecto.Migration

  def change do
    create table(:invites) do
      add :code, :string
      add :active, :boolean, default: false, null: false
      add :owner_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create unique_index(:invites, [:code])
    create index(:invites, [:owner_id])
  end
end
