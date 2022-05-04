defmodule Platform.Repo.Migrations.AddAdminNotes do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :admin_notes, :string, default: ""
    end
  end
end
