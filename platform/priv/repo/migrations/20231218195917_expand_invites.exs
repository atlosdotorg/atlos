defmodule Platform.Repo.Migrations.ExpandInvites do
  use Ecto.Migration

  def change do
    alter table(:invites) do
      add :expires, :naive_datetime, default: nil, null: true
      add :single_use, :boolean, default: false
      add :project_id, references(:projects, type: :binary_id), null: true
      add :project_access_level, :string, default: nil, null: true
    end
  end
end
