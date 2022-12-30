defmodule Platform.ProjectsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Platform.Projects` context.
  """

  @doc """
  Generate a project.
  """
  def project_fixture(attrs \\ %{}) do
    {:ok, project} =
      attrs
      |> Enum.into(%{
        code: "some code",
        name: "some name"
      })
      |> Platform.Projects.create_project()

    project
  end
end
