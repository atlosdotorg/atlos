defmodule Platform.Projects.ProjectMembership do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "project_memberships" do
    field :role, Ecto.Enum, values: [:owner, :manager, :editor, :viewer]
    belongs_to(:user, Platform.Accounts.User, type: :id)
    belongs_to(:project, Platform.Projects.Project, type: :binary_id)

    field :username, :string, virtual: true

    timestamps()
  end

  @doc false
  def changeset(project_membership, attrs, opts \\ []) do
    all_memberships = Keyword.get(opts, :all_memberships, [])

    project_membership
    |> cast(attrs, [:role, :username, :project_id])
    |> validate_required([:role])
    |> validate_inclusion(:role, [:owner, :manager, :editor, :viewer])
    |> validate_username()
    |> validate_required([:user_id, :project_id])
    |> unique_constraint([:user_id, :project_id],
      error_key: :username,
      message: "This user is already a member of this project."
    )
    # If they are the owner and they are the only owner, don't allow them to change their role
    |> validate_change(:role, fn :role, _value ->
      if is_list(all_memberships) and project_membership.role == :owner and
           Enum.filter(all_memberships, fn pm -> pm.role == :owner end) |> Enum.count() == 1 do
        [
          role:
            "This is the only owner of the project, so you cannot change their role. To change their role, you must first add another owner."
        ]
      else
        []
      end
    end)
  end

  def validate_username(changeset) do
    username = get_change(changeset, :username)

    if username do
      case Platform.Accounts.get_user_by_username(username) do
        nil ->
          add_error(changeset, :username, "This user does not exist.")

        user ->
          put_change(changeset, :user_id, user.id)
      end
    else
      # If available, get the username from the user_id (provided it's preloaded)
      changeset
      |> get_field(:user)
      |> case do
        nil -> changeset
        user -> put_change(changeset, :username, user.username)
      end
    end
  end
end
