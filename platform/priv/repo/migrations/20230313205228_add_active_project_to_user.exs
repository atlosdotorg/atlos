defmodule Platform.Repo.Migrations.AddActiveProjectToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :active_project_membership_id,
          references(:project_memberships, on_delete: :nilify_all, type: :binary_id)
    end
  end
end
