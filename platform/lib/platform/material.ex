defmodule Platform.Material do
  @moduledoc """
  The Material context.
  """

  import Ecto.Query, warn: false
  alias Platform.Repo

  alias Platform.Material.Media
  alias Platform.Material.Attribute
  alias Platform.Material.MediaVersion
  alias Platform.Utils
  alias Platform.Updates
  alias Platform.Updates.Update
  alias Platform.Accounts.User

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
    query |> preload([:versions])
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

  def create_media_logged(%User{} = user, attrs \\ %{}) do
    Repo.transaction(fn ->
      {:ok, media} =
        %Media{}
        |> Media.changeset(attrs)
        |> Repo.insert()

      {:ok, _} =
        Updates.change_from_media_creation(media, user) |> Updates.create_update_from_changeset()

      media
    end)
  end

  def get_full_media_by_slug(slug) do
    Media |> preload_media_versions() |> Repo.get_by(slug: slug)
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

  @doc """
  Preprocesses the given media and uploads it to persistent storage.

  Returns {:ok, file_path, thumbnail_path, duration}
  """
  def process_uploaded_media(path, mime, identifier) do
    thumb_path = Temp.path!(%{prefix: identifier, suffix: "thumbnail.jpg"})
    :ok = Thumbnex.create_thumbnail(path, thumb_path)

    media_path =
      cond do
        String.starts_with?(mime, "image/") -> Temp.path!(%{suffix: ".jpg", prefix: identifier})
        String.starts_with?(mime, "video/") -> Temp.path!(%{suffix: ".mp4", prefix: identifier})
      end

    font_path = "priv/static/fonts/iosevka-bold.ttc"

    process_command =
      FFmpex.new_command()
      |> FFmpex.add_input_file(path)
      |> FFmpex.add_output_file(media_path)
      |> FFmpex.add_file_option(
        FFmpex.Options.Video.option_vf(
          "drawtext=text='#{identifier}':x=20:y=20:fontfile=#{font_path}:fontsize=24:fontcolor=white:box=1:boxcolor=black@0.25:boxborderw=5"
        )
      )

    {:ok, _} = FFmpex.execute(process_command)

    {:ok, out_data} = FFprobe.format(media_path)

    {duration, _} = Integer.parse(out_data["duration"])
    {size, _} = Integer.parse(out_data["size"])

    {:ok, new_thumb_path} = Utils.upload_ugc_file(thumb_path)
    {:ok, new_path} = Utils.upload_ugc_file(media_path)

    {:ok, new_path, new_thumb_path, duration, size}
  end

  def media_version_location(version) do
    # This may in the future create a signed URL at the CDN provider, for example
    version.file_location
  end

  def change_media_attribute(media, %Attribute{} = attribute, attrs \\ %{}) do
    Attribute.changeset(media, attribute, attrs)
  end

  def update_media_attribute(media, %Attribute{} = attribute, attrs) do
    media
    |> Attribute.changeset(attribute, attrs)
    |> Repo.update()
  end

  def update_media_attribute_logged(media, %Attribute{} = attribute, user, attrs) do
    media_changeset = change_media_attribute(media, attribute, attrs)

    update_changeset =
      Updates.change_from_attribute_changeset(media, attribute, user, media_changeset, attrs)

    # Make sure both changesets are valid before inserting
    cond do
      !(media_changeset.valid? && update_changeset.valid?) ->
        media_changeset

      true ->
        Repo.transaction(fn ->
          {:ok, _} = Updates.create_update_from_changeset(update_changeset)
          update_media_attribute(media, attribute, attrs)
        end)
    end
  end
end
