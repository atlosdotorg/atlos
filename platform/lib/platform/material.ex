defmodule Platform.Material do
  @moduledoc """
  The Material context.
  """

  import Ecto.Query, warn: false
  alias Platform.Repo

  alias Platform.Material.Media

  @doc """
  Returns the list of media.

  ## Examples

      iex> list_media()
      [%Media{}, ...]

  """
  def list_media do
    Repo.all(Media)
  end

  defp preload_media_versions(query) do
    query |> preload([:media_versions])
  end

  @doc """
  Gets a single media.

  Raises `Ecto.NoResultsError` if the Media does not exist.

  ## Examples

      iex> get_media!(123)
      %Media{}

      iex> get_media!(456)
      ** (Ecto.NoResultsError)

  """
  def get_media!(id), do: Repo.get!(Media, id)

  @doc """
  Creates a media.

  ## Examples

      iex> create_media(%{field: value})
      {:ok, %Media{}}

      iex> create_media(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_media(attrs \\ %{}) do
    %Media{}
    |> Media.changeset(attrs)
    |> Repo.insert()
  end

  def get_media_with_versions(id) do
    Media |> preload_media_versions() |> Repo.get!(id)
  end

  @doc """
  Updates a media.

  ## Examples

      iex> update_media(media, %{field: new_value})
      {:ok, %Media{}}

      iex> update_media(media, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_media(%Media{} = media, attrs) do
    media
    |> Media.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a media.

  ## Examples

      iex> delete_media(media)
      {:ok, %Media{}}

      iex> delete_media(media)
      {:error, %Ecto.Changeset{}}

  """
  def delete_media(%Media{} = media) do
    Repo.delete(media)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking media changes.

  ## Examples

      iex> change_media(media)
      %Ecto.Changeset{data: %Media{}}

  """
  def change_media(%Media{} = media, attrs \\ %{}) do
    Media.changeset(media, attrs)
  end

  alias Platform.Material.MediaVersion

  @doc """
  Returns the list of media_versions.

  ## Examples

      iex> list_media_versions()
      [%MediaVersion{}, ...]

  """
  def list_media_versions do
    Repo.all(MediaVersion)
  end

  @doc """
  Gets a single media_version.

  Raises `Ecto.NoResultsError` if the Media version does not exist.

  ## Examples

      iex> get_media_version!(123)
      %MediaVersion{}

      iex> get_media_version!(456)
      ** (Ecto.NoResultsError)

  """
  def get_media_version!(id), do: Repo.get!(MediaVersion, id)

  @doc """
  Creates a media_version.

  ## Examples

      iex> create_media_version(%{field: value})
      {:ok, %MediaVersion{}}

      iex> create_media_version(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_media_version(attrs \\ %{}) do
    %MediaVersion{}
    |> MediaVersion.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a media_version.

  ## Examples

      iex> update_media_version(media_version, %{field: new_value})
      {:ok, %MediaVersion{}}

      iex> update_media_version(media_version, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_media_version(%MediaVersion{} = media_version, attrs) do
    media_version
    |> MediaVersion.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a media_version.

  ## Examples

      iex> delete_media_version(media_version)
      {:ok, %MediaVersion{}}

      iex> delete_media_version(media_version)
      {:error, %Ecto.Changeset{}}

  """
  def delete_media_version(%MediaVersion{} = media_version) do
    Repo.delete(media_version)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking media_version changes.

  ## Examples

      iex> change_media_version(media_version)
      %Ecto.Changeset{data: %MediaVersion{}}

  """
  def change_media_version(%MediaVersion{} = media_version, attrs \\ %{}) do
    MediaVersion.changeset(media_version, attrs)
  end
end
