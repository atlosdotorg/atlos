defmodule Platform.Material do
  @moduledoc """
  The Material context.
  """

  import Ecto.Query, warn: false
  alias Platform.Repo
  require Logger

  alias Phoenix.PubSub

  alias Platform.Material.Media
  alias Platform.Material.Attribute
  alias Platform.Material.MediaVersion
  alias Platform.Material.MediaSubscription
  alias Platform.Utils
  alias Platform.Updates
  alias Platform.Accounts.User
  alias Platform.Uploads
  alias Platform.Accounts

  defp hydrate_media_query(query) do
    query
    |> preload_media_versions()
    |> preload_media_updates()
  end

  @doc """
  Returns the list of media. Will preload the versions and updates.

  ## Examples

      iex> list_media()
      [%Media{}, ...]

  """
  def list_media do
    Media
    |> hydrate_media_query()
    |> order_by(desc: :updated_at)
    |> Repo.all()
  end

  defp _query_media(query) do
    # Helper function used to abstract behavior of the `query_media` functions.
    query
    |> hydrate_media_query()
    |> order_by(desc: :updated_at)
  end

  @doc """
  Query the list of media. Will preload the versions and updates.
  """
  def query_media(query \\ Media) do
    _query_media(query)
    |> Repo.all()
  end

  @doc """
  Query the list of media, paginated. Will preload the versions and updates. Behavior otherwise the same as query_media/1.
  """
  def query_media_paginated(query \\ Media, opts \\ []) do
    applied_options = Keyword.merge([cursor_fields: [{:updated_at, :desc}], limit: 30], opts)

    _query_media(query)
    |> Repo.paginate(applied_options)
  end

  @doc """
  Returns the list of media subscribed to by the given user.
  """
  def list_subscribed_media(%User{} = user) do
    user
    |> Ecto.assoc(:subscribed_media)
    |> order_by(desc: :updated_at)
    |> hydrate_media_query()
    |> Repo.all()
  end

  @doc """
  Returns the list of geolocated media.
  """
  def list_geolocated_media() do
    Media
    |> where([i], not is_nil(i.attr_geolocation))
    |> hydrate_media_query()
    |> Repo.all()
  end

  @doc """
  Returns all the media that do not have any versions uploaded.
  """
  def list_unarchived_media() do
    from(m in Media,
      where:
        fragment("NOT EXISTS (SELECT * FROM media_versions other WHERE other.media_id = ?)", m.id)
    )
    |> hydrate_media_query()
    |> Repo.all()
  end

  defp preload_media_versions(query) do
    query |> preload([:versions])
  end

  defp preload_media_updates(query) do
    # TODO: should this be pulled into the Updates context somehow?
    query |> preload(updates: [:user, :media, :media_version])
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

  def create_media_audited(%User{} = user, attrs \\ %{}) do
    changeset =
      %Media{}
      |> Media.changeset(attrs)

    cond do
      !changeset.valid? ->
        {:error, changeset}

      true ->
        Repo.transaction(fn ->
          {:ok, media} =
            %Media{}
            |> Media.changeset(attrs)
            |> Repo.insert()

          {:ok, _} =
            Updates.change_from_media_creation(media, user)
            |> Updates.create_update_from_changeset()

          media
        end)
    end
  end

  def get_full_media_by_slug(slug) do
    Media |> preload_media_versions() |> preload_media_updates() |> Repo.get_by(slug: slug)
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
  A changeset meant to be paired with bulk uploads.
  """
  def bulk_import_change(media \\ %Media{}, attrs) do
    Media.import_changeset(media, attrs)
  end

  @doc """
  Create the given media from the given attributes, which are assumed to be from
  import data. The Atlos bot account will also leave a comment that links to the
  provided source media URLs.
  """
  def bulk_import_create(media \\ %Media{}, attrs) do
    Repo.transaction(fn ->
      bot_account = Accounts.get_auto_account()

      changeset = Media.import_changeset(media, attrs)

      {:ok, media} =
        changeset
        |> Repo.insert()

      {:ok, _} =
        Updates.change_from_media_creation(media, bot_account)
        |> Updates.create_update_from_changeset()

      sources =
        attrs
        |> Map.to_list()
        |> Enum.filter(fn {k, v} ->
          # Only include strings that aren't empty
          String.starts_with?(k, "source_") && is_bitstring(v) &&
            String.length(v |> String.trim()) > 0
        end)
        |> Enum.map(fn {_k, v} -> v end)

      {:ok, _} =
        Updates.change_from_comment(media, bot_account, %{
          "explanation" =>
            "This incident was created via **bulk import**, so some attributes are pre-filled." <>
              if(length(sources) > 0,
                do:
                  "\n\nSource media for this incident is available at the following URLs, which Atlos will attempt to automatically archive:\n\n" <>
                    Enum.join(sources |> Enum.map(&("- " <> &1)), "\n"),
                else: ""
              )
        })
        |> Updates.create_update_from_changeset()

      # Attempt to archive all media versions
      for source <- sources do
        {:ok, version} =
          create_media_version(media, %{
            upload_type: :direct,
            status: :pending,
            source_url: source,
            media_id: media.id
          })

        archive_media_version(version, priority: 3, hide_version_on_failure: true)
      end

      media
    end)
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

  def pubsub_topic_for_media(id) do
    "media_updates:#{id}"
  end

  @doc """
  Broadcast that the media was updated on its PubSub channel.
  """
  def broadcast_media_updated(media_id) do
    Task.start(fn ->
      # Add a delay to let everything settle. There's probably a way to do this more robustly.
      :timer.sleep(500)
      PubSub.broadcast(Platform.PubSub, pubsub_topic_for_media(media_id), {:media_updated})
    end)
  end

  def get_media_versions_by_source_url(url) do
    Repo.all(
      from v in MediaVersion,
        where: v.source_url == ^url,
        preload: [media: [[updates: :user], :versions]]
    )
    |> Enum.sort_by(& &1.media.id)
    |> Enum.dedup_by(& &1.media.id)
  end

  def create_media_version(%Media{} = media, attrs \\ %{}) do
    %MediaVersion{}
    |> MediaVersion.changeset(attrs |> Map.put("media_id", media.id) |> Utils.make_keys_strings())
    |> Repo.insert()
  end

  def create_media_version_audited(
        %Media{} = media,
        %User{} = user,
        attrs \\ %{}
      ) do
    if Media.can_user_edit(media, user) do
      Repo.transaction(fn ->
        with {:ok, version} <- create_media_version(media, attrs),
             update_changeset <- Updates.change_from_media_version_upload(media, user, version),
             {:ok, _} <- Updates.create_update_from_changeset(update_changeset) do
          version
        else
          _ -> {:error, change_media_version(%MediaVersion{}, attrs)}
        end
      end)
    else
      # Note: Updates.create_update_from_changeset will also catch the permissions error, but it's good to have multiple layers.
      {:error,
       change_media_version(%MediaVersion{}, attrs)
       |> Ecto.Changeset.add_error(:source_url, "This media has been locked.")}
    end
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
  Performs an archive of the given media version. Status must be pending.

  Options:
  - priority: 0-3, the priority (default 1)
  - hide_version_on_failure: true/false, whether to hide versions that failed
  """
  def archive_media_version(
        %MediaVersion{status: :pending, media_id: media_id, id: id} = version,
        opts \\ []
      ) do
    %{
      "media_version_id" => id,
      "hide_version_on_failure" => Keyword.get(opts, :hide_version_on_failure, false)
    }
    |> Platform.Workers.Archiver.new(priority: Keyword.get(opts, :priority, 1))
    |> Oban.insert!()
  end

  def media_version_location(version, media) do
    cond do
      is_nil(version.file_location) ->
        nil

      String.starts_with?(version.file_location, "https://") ->
        version.file_location

      true ->
        Uploads.WatermarkedMediaVersion.url({version.file_location, media}, :original,
          signed: true
        )
    end
  end

  @doc """
  Changeset for the media attribute. Also checks permissions.
  """
  def change_media_attribute(
        %Media{} = media,
        %Attribute{} = attribute,
        %User{} = user,
        attrs \\ %{}
      ) do
    changeset = Attribute.changeset(media, attribute, attrs, user)

    if Attribute.can_user_edit(attribute, user, media) do
      changeset
    else
      changeset
      |> Ecto.Changeset.add_error(
        attribute.schema_field,
        "You do not have permission to edit this attribute."
      )
    end
  end

  def update_media_attribute(media, %Attribute{} = attribute, attrs, user \\ nil) do
    media
    |> Attribute.changeset(attribute, attrs, user)
    |> Repo.update()
  end

  @doc """
  Do an audited update of the given attribute. Will broadcast change via PubSub.
  """
  def update_media_attribute_audited(media, %Attribute{} = attribute, %User{} = user, attrs) do
    media_changeset = change_media_attribute(media, attribute, user, attrs)

    update_changeset =
      Updates.change_from_attribute_changeset(media, attribute, user, media_changeset, attrs)

    # Make sure both changesets are valid
    cond do
      !(media_changeset.valid? && update_changeset.valid?) ->
        {:error, media_changeset}

      true ->
        Repo.transaction(fn ->
          {:ok, _} = Updates.create_update_from_changeset(update_changeset)
          {:ok, res} = update_media_attribute(media, attribute, attrs, user)
          res
        end)
    end
  end

  def get_subscription(%Media{} = media, %User{} = user) do
    Repo.get_by(MediaSubscription, media_id: media.id, user_id: user.id)
  end

  def subscribe_user(%Media{} = media, %User{} = user) do
    MediaSubscription.changeset(%MediaSubscription{}, %{media_id: media.id, user_id: user.id})
    |> Repo.insert()
  end

  def unsubscribe_user(%Media{} = media, %User{} = user) do
    with {1, _} <-
           from(s in MediaSubscription,
             where: s.media_id == ^media.id,
             where: s.user_id == ^user.id
           )
           |> Repo.delete_all() do
      :ok
    else
      _ -> :error
    end
  end

  def total_subscribed!(%Media{} = media) do
    [count] =
      Repo.all(
        from w in MediaSubscription,
          where: w.media_id == ^media.id,
          select: count()
      )

    count
  end

  def media_thumbnail(%Media{} = media) do
    case Enum.find(
           media.versions |> Enum.sort_by(& &1.updated_at) |> Enum.reverse(),
           &(!(&1.visibility != :visible or is_nil(&1.file_location)))
         ) do
      nil ->
        nil

      val ->
        if String.starts_with?(val.file_location, "https://"),
          # This allows us to have easy demo data — just give a raw HTTPS URL
          do: val.file_location,
          else:
            Uploads.WatermarkedMediaVersion.url({val.file_location, media}, :thumb, signed: true)
    end
  end

  def contributors(%Media{} = media) do
    Enum.uniq(media.updates |> Enum.filter(&(not &1.hidden)) |> Enum.map(& &1.user))
  end

  @doc """
  Get the unique values of the given attribute across *all* media. Will hit the database.
  """
  def get_values_of_attribute(%Attribute{type: :multi_select} = attribute) do
    Media
    |> select([m], fragment("unnest(?)", field(m, ^attribute.schema_field)))
    |> distinct(true)
    |> Repo.all()
  end
end
