defmodule Platform.Repo.Migrations.AddUpdateAttachments do
  use Ecto.Migration

  def change do
    alter table(:updates) do
      add :attachments, {:array, :string}, default: []
    end
  end
end
