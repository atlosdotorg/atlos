defmodule Platform.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  alias Platform.Projects.ProjectAttribute
  alias Platform.Repo

  alias Platform.Projects.Project
  alias Platform.Accounts

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
    list_projects() |> Enum.filter(&can_view_project?(user, &1))
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
  Creates a project.

  ## Examples

      iex> create_project(%{field: value})
      {:ok, %Project{}}

      iex> create_project(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_project(attrs \\ %{}, user \\ nil) do
    # Verify the user has permission to create
    unless is_nil(user) || can_create_project?(user) do
      raise "User does not have permission to create a project"
    end

    %Project{}
    |> Project.changeset(attrs)
    |> Ecto.Changeset.put_embed(:attributes, ProjectAttribute.default_attributes())
    |> Repo.insert()
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
    unless is_nil(user) || can_edit_project?(user, project) do
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
    unless is_nil(user) || can_edit_project?(user, project) do
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

  @doc """
  Returns whether the given user can edit a project's media.
  """
  def can_edit_media?(%Accounts.User{} = _user, %Project{} = _project) do
    # TODO: Eventually we will handle permissions on a per-project basis.
    true
  end

  @doc """
  Returns whether the given user can edit a project.
  """
  def can_edit_project?(%Accounts.User{} = user, %Project{} = _project) do
    Accounts.is_privileged(user)
  end

  @doc """
  Returns whether the given user create a new project.
  """
  def can_create_project?(%Accounts.User{} = user) do
    Accounts.is_privileged(user)
  end

  @doc """
  Returns whether the given user can view the project.
  """
  def can_view_project?(%Accounts.User{} = _user, %Project{} = _project) do
    true
  end
end
