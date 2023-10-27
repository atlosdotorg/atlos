defmodule Platform.Repo.Migrations.ChangeStatusDefault do
  use Ecto.Migration

  def change do
    execute "ALTER TABLE media ALTER COLUMN attr_status SET DEFAULT 'To Do'",
            "ALTER TABLE media ALTER COLUMN attr_status SET DEFAULT 'Unclaimed'"

    execute "UPDATE media SET attr_status = 'To Do' where attr_status = 'Unclaimed'",
            "UPDATE media SET attr_status = 'Unclaimed' where attr_status = 'To Do'"
  end
end
