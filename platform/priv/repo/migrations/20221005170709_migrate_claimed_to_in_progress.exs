defmodule Platform.Repo.Migrations.MigrateClaimedToInProgress do
  use Ecto.Migration

  def up do
    execute """
    update media set attr_status = 'In Progress' where attr_status = 'Claimed'
    """
  end

  def down do
    execute """
    update media set attr_status = 'Claimed' where attr_status = 'In Progress'
    """
  end
end
