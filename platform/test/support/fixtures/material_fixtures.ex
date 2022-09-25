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
        attr_description: "some description",
        attr_sensitive: ["Graphic Violence"],
        attr_type: ["Other"],
        slug: unique_media_slug(),
        status: "Unclaimed"
      })
      |> Platform.Material.create_media()

    media
  end

  @doc """
  Generate a media_version.
  """
  def media_version_fixture(attrs \\ %{}) do
    {:ok, media_version} =
      media_fixture()
      |> Platform.Material.create_media_version(
        attrs
        |> Enum.into(%{
          file_location: "some file_location",
          file_size: 42,
          perceptual_hash: "some perceptual_hash",
          source_url: "some source_url",
          type: :image,
          duration_seconds: 30,
          mime_type: "image/png",
          client_name: "upload.png"
        })
      )

    media_version
  end
end
