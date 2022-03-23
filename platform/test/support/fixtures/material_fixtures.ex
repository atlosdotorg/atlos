defmodule Platform.MaterialFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Platform.Material` context.
  """

  @doc """
  Generate a unique media slug.
  """
  def unique_media_slug, do: "some slug#{System.unique_integer([:positive])}"

  @doc """
  Generate a media.
  """
  def media_fixture(attrs \\ %{}) do
    {:ok, media} =
      attrs
      |> Enum.into(%{
        description: "some description",
        slug: unique_media_slug()
      })
      |> Platform.Material.create_media()

    media
  end
end
