defmodule Platform.Repo.Migrations.RenameStatusValues do
  use Ecto.Migration

  def change do
    # Rename "Unclaimed" to "In Progress" in the "status" column of the "media" table
    execute "UPDATE media SET attr_status = 'To Do' where attr_status = 'Unclaimed'",
            "UPDATE media SET attr_status = 'Unclaimed' where attr_status = 'To Do'"
  end
end
