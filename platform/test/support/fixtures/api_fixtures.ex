defmodule Platform.APIFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Platform.API` context.
  """

  @doc """
  Generate a api_token.
  """
  def api_token_fixture(attrs \\ %{}) do
    {:ok, api_token} =
      attrs
      |> Enum.into(%{
        name: "some name",
        description: "some description",
        project_id: Platform.ProjectsFixtures.project_fixture().id,
        creator_id: Platform.Accounts.get_auto_account().id
      })
      |> Platform.API.create_api_token()

    api_token
  end

  @doc """
  Generate a legacy api_token.
  """
  def api_token_fixture_legacy(attrs \\ %{}) do
    {:ok, api_token} =
      attrs
      |> Enum.into(%{
        name: "some name",
        description: "some description",
        project_id: Platform.ProjectsFixtures.project_fixture().id,
        creator_id: Platform.Accounts.get_auto_account().id
      })
      |> Platform.API.create_api_token(legacy: true)

    api_token
  end
end
