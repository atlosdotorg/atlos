defmodule Platform.Repo.Migrations.MarkHiddenAsVisible do
  use Ecto.Migration

  def up do
    execute """
    update media_versions set visibility = 'visible' where visibility = 'hidden';
    """
  end

  def down do
    # pass
  end
end
