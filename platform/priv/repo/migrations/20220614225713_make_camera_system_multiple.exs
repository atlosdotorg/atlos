defmodule Platform.Repo.Migrations.MakeCameraSystemMultiple do
  use Ecto.Migration

  def change do
    alter table(:media) do
      remove :attr_camera_system
      add :attr_camera_system, {:array, :string}
    end
  end
end
