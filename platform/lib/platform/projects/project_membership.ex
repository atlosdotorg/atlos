defmodule Platform.Projects.ProjectMembership do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "project_memberships" do
    field :role, Ecto.Enum, values: [:owner, :manager, :editor, :viewer]
    belongs_to(:user, Platform.Accounts.User)
    belongs_to(:project, Platform.Projects.Project, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(project_membership, attrs) do
    project_membership
    |> cast(attrs, [:role])
    |> validate_required([:role])
  end
end
