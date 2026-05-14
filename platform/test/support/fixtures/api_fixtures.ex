defmodule Platform.APIFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Platform.API` context.
  """

  @doc """
  Generate a project-scoped v2 api_token. If `:project_id` isn't in attrs,
  a fresh project is created.
  """
  def api_token_fixture(attrs \\ %{}) do
    {project, attrs} =
      case Map.pop(attrs, :project_id) do
        {nil, attrs} -> {Platform.ProjectsFixtures.project_fixture(), attrs}
        {id, attrs} -> {Platform.Projects.get_project!(id), attrs}
      end

    creator = Platform.Accounts.get_auto_account()

    full_attrs =
      attrs
      |> Enum.into(%{
        name: "some name",
        description: "some description"
      })

    {:ok, api_token} = Platform.API.create_api_token(project, creator, full_attrs)
    api_token
  end

  @doc """
  Generate a legacy v1 api_token.
  """
  def api_token_fixture_legacy(attrs \\ %{}) do
    admin = Platform.AccountsFixtures.admin_user_fixture()

    full_attrs =
      attrs
      |> Enum.into(%{
        name: "some name",
        description: "some description"
      })

    {:ok, api_token} = Platform.API.create_api_token(nil, admin, full_attrs, legacy: true)

    api_token
  end

  @doc """
  Generate an instance-wide v2 api_token (admin-created, no project scope).
  """
  def api_token_fixture_instance_wide_v2(attrs \\ %{}) do
    admin = Platform.AccountsFixtures.admin_user_fixture()

    full_attrs =
      attrs
      |> Enum.into(%{
        name: "some name",
        description: "some description",
        permissions: [:read, :comment, :edit]
      })

    {:ok, api_token} = Platform.API.create_api_token(nil, admin, full_attrs)
    api_token
  end
end
