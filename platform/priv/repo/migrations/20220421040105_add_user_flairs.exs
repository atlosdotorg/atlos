defmodule Platform.Repo.Migrations.AddUserFlairs do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :flair, :string, default: ""
    end
  end
end
