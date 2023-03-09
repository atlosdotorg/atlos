defmodule Platform.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  alias Platform.Projects.ProjectAttribute
  alias Platform.Repo

  alias Platform.Projects.Project
  alias Platform.Accounts
  alias Platform.Permissions

  use Memoize

  @doc """
  Returns the list of projects.

  ## Examples

      iex> list_projects()
      [%Project{}, ...]

  """
  def list_projects do
    Repo.all(Project)
  end

  def list_projects_for_user(%Accounts.User{} = user) do
    # TODO: This is a temporary solution. We should be using a query to get the projects for the user.
    list_projects() |> Enum.filter(&Permissions.can_view_project?(user, &1))
  end

  @doc """
  Gets a single project.

  Raises `Ecto.NoResultsError` if the Project does not exist.

  ## Examples

      iex> get_project!(123)
      %Project{}

      iex> get_project!(456)
      ** (Ecto.NoResultsError)

  """
  def get_project!(id), do: Repo.get!(Project, id)

  @doc """
  Gets a single project. Returns `nil` if the Project does not exist.

  ## Examples

      iex> get_project(123)
      %Project{}

      iex> get_project(456)
      nil
  """
  def get_project(""), do: nil
  def get_project("unset"), do: nil
  def get_project(nil), do: nil
  def get_project(id), do: Repo.get(Project, id)

  @doc """
  Creates a project. If the user is not nil, it will add the user as an owner of the project.

  ## Examples

      iex> create_project(%{field: value})
      {:ok, %Project{}}

      iex> create_project(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_project(attrs \\ %{}, user \\ nil) do
    # Verify the user has permission to create
    unless is_nil(user) || Permissions.can_create_project?(user) do
      raise "User does not have permission to create a project"
    end

    result =
      %Project{}
      |> Project.changeset(attrs)
      |> Ecto.Changeset.put_embed(:attributes, ProjectAttribute.default_attributes())
      |> Repo.insert()

    # If the user is not nil, add them as an owner of the project
    case result do
      {:ok, project} ->
        if not is_nil(user) do
          create_project_membership(%{
            project_id: project.id,
            username: user.username,
            role: :owner
          })
        end

        {:ok, project}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates a project.

  ## Examples

      iex> update_project(project, %{field: new_value})
      {:ok, %Project{}}

      iex> update_project(project, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_project(%Project{} = project, attrs, user \\ nil) do
    # Verify the user has permission to edit the project
    unless is_nil(user) || Permissions.can_edit_project_metadata?(user, project) do
      raise "User does not have permission to edit this project"
    end

    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a project.

  ## Examples

      iex> delete_project(project)
      {:ok, %Project{}}

      iex> delete_project(project)
      {:error, %Ecto.Changeset{}}

  """
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  @doc """
  Deletes an embedded custom project attribute. Checks user permission.

  ## Examples

      iex> delete_project_attribute(project, "existing_id")
      {:ok, %Project{}}

      iex> delete_project_attribute(project, "non_existing_id")
      {:error, %Ecto.Changeset{}}
  """
  def delete_project_attribute(%Project{} = project, id, user \\ nil) do
    # Verify the user has permission to edit the project
    unless is_nil(user) || Permissions.can_edit_project_metadata?(user, project) do
      raise "User does not have permission to edit this project"
    end

    # Verify the attribute exists
    unless Enum.any?(project.attributes, fn attr -> attr.id == id end) do
      raise "Attribute does not exist"
    end

    # Delete the attribute
    change_project(project)
    |> Ecto.Changeset.put_embed(
      :attributes,
      project.attributes
      |> Enum.map(fn attr ->
        if attr.id == id do
          ProjectAttribute.changeset(attr) |> Map.put(:action, :delete)
        else
          attr
        end
      end)
    )
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project changes.

  ## Examples

      iex> change_project(project)
      %Ecto.Changeset{data: %Project{}}

  """
  def change_project(%Project{} = project, attrs \\ %{}) do
    Project.changeset(project, attrs)
  end

  alias Platform.Projects.ProjectMembership

  defp preload_project_memberships(query) do
    query
    |> preload([:user, :project])
  end

  @doc """
  Returns the list of project_memberships.

  ## Examples

      iex> list_project_memberships()
      [%ProjectMembership{}, ...]

  """
  def list_project_memberships do
    Repo.all(ProjectMembership)
  end

  @doc """
  Gets a single project_membership.

  Raises `Ecto.NoResultsError` if the Project membership does not exist.

  ## Examples

      iex> get_project_membership!(123)
      %ProjectMembership{}

      iex> get_project_membership!(456)
      ** (Ecto.NoResultsError)

  """
  def get_project_membership!(id),
    do: Repo.get!(ProjectMembership |> preload_project_memberships(), id)

  @doc """
  Gets a single project_membership by the user and project.
  """
  def get_project_membership_by_user_and_project(%Accounts.User{} = user, %Project{} = project),
    do: get_project_membership_by_user_and_project_id(user, project.id)

  def get_project_membership_by_user_and_project(_, _), do: nil

  def get_project_membership_by_user_and_project_id(_, nil), do: nil

  def get_project_membership_by_user_and_project_id(%Accounts.User{} = user, project_id) do
    get_project_membership_by_user_id_and_project_id(user.id, project_id)
  end

  defmemo get_project_membership_by_user_id_and_project_id(user_id, project_id), expires_in: 1000 do
    Repo.get_by(ProjectMembership |> preload_project_memberships(),
      user_id: user_id,
      project_id: project_id
    )
  end

  @doc """
  Gets the project relationships for a given project.
  """
  def get_project_memberships(%Project{} = project) do
    Repo.all(
      from(pm in (ProjectMembership |> preload_project_memberships()),
        where: pm.project_id == ^project.id
      )
    )
  end

  @doc """
  Gets the project memberships for a user.
  """
  def get_users_project_memberships(%Accounts.User{} = user) do
    Repo.all(
      from(pm in (ProjectMembership |> preload_project_memberships()),
        where: pm.user_id == ^user.id
      )
    )
  end

  @doc """
  Creates a project_membership.

  ## Examples

      iex> create_project_membership(%{field: value})
      {:ok, %ProjectMembership{}}

      iex> create_project_membership(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_project_membership(attrs \\ %{}) do
    %ProjectMembership{}
    |> ProjectMembership.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, val} -> {:ok, Repo.preload(val, [:user, :project])}
      v -> v
    end
  end

  @doc """
  Get the users for a project.
  """
  def get_project_users(%Project{} = project) do
    Repo.all(
      from(pm in (ProjectMembership |> preload_project_memberships()),
        where: pm.project_id == ^project.id
      )
    )
    |> Enum.map(fn pm -> pm.user end)
  end

  @doc """
  Updates a project_membership.

  ## Examples

      iex> update_project_membership(project_membership, %{field: new_value})
      {:ok, %ProjectMembership{}}

      iex> update_project_membership(project_membership, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_project_membership(%ProjectMembership{} = project_membership, attrs, opts \\ []) do
    project_membership
    |> ProjectMembership.changeset(attrs, opts)
    |> Repo.update()
    |> case do
      {:ok, val} -> {:ok, Repo.preload(val, [:user, :project])}
      v -> v
    end
  end

  @doc """
  Deletes a project_membership.

  ## Examples

      iex> delete_project_membership(project_membership)
      {:ok, %ProjectMembership{}}

      iex> delete_project_membership(project_membership)
      {:error, %Ecto.Changeset{}}

  """
  def delete_project_membership(%ProjectMembership{} = project_membership) do
    Repo.delete(project_membership)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking project_membership changes.

  ## Examples

      iex> change_project_membership(project_membership)
      %Ecto.Changeset{data: %ProjectMembership{}}

  """
  def change_project_membership(
        %ProjectMembership{} = project_membership,
        attrs \\ %{},
        opts \\ []
      ) do
    ProjectMembership.changeset(project_membership, attrs, opts)
  end
end
