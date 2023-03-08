defmodule Platform.ProjectsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Platform.Projects` context.
  """

  @doc """
  Generate a project.
  """
  def project_fixture(attrs \\ %{}, opts \\ []) do
    {:ok, project} =
      attrs
      |> Enum.into(%{
        code: "code1",
        name: "some name"
      })
      |> Platform.Projects.create_project()

    owner = Keyword.get(opts, :owner)

    if not is_nil(owner) do
      {:ok, _} =
        Platform.Projects.create_project_membership(%{
          project_id: project.id,
          username: owner.username,
          role: :owner
        })
    end

    project
  end

  @doc """
  Generate a project_membership.
  """
  def project_membership_fixture(attrs \\ %{}) do
    {:ok, project_membership} =
      attrs
      |> Enum.into(%{
        role: :owner,
        project_id: project_fixture().id,
        username: Platform.AccountsFixtures.user_fixture().username
      })
      |> Platform.Projects.create_project_membership()

    project_membership |> Platform.Repo.preload([:user, :project])
  end
end
