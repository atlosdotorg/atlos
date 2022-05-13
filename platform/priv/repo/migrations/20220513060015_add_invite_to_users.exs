defmodule Platform.Repo.Migrations.AddInviteToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :invite_id, references(:invites, on_delete: :nothing)
    end

    create index(:users, [:invite_id])
  end
end
