defmodule Platform.MaterialFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Platform.Material` context.
  """

  import Platform.ProjectsFixtures

  @doc """
  Generate a unique media slug.
  """
  def unique_media_slug, do: "some slug#{System.unique_integer([:positive])}"

  @doc """
  Generate a media.
  """
  def media_fixture(attrs \\ %{}, opts \\ []) do
    {:ok, media} =
      attrs
      |> Enum.into(%{
        attr_description: "some description",
        attr_sensitive: ["Graphic Violence"],
        attr_type: ["Other"],
        slug: unique_media_slug(),
        status: "To Do",
        project_id: project_fixture().id
      })
      |> Platform.Material.create_media()

    for_user = Keyword.get(opts, :for_user)

    if for_user do
      {:ok, _} =
        Platform.Projects.create_project_membership(%{
          project_id: media.project_id,
          username: for_user.username,
          role: :editor
        })
    end

    # So that everything is preloaded
    Platform.Material.get_media!(media.id)
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
