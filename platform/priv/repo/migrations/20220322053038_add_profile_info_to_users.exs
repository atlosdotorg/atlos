defmodule Platform.Repo.Migrations.AddProfileInfoToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :bio, :string
      add :profile_photo_file, :string, default: ""
    end
  end
end
