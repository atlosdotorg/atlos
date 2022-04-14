defmodule Platform.Repo.Migrations.AddFlagAttribute do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :attr_flag, :string
    end
  end
end
