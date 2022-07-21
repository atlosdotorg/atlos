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
        description: "some description",
        value: "some value"
      })
      |> Platform.API.create_api_token()

    api_token
  end
end
