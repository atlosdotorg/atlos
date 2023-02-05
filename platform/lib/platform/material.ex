defmodule Platform.Material do
  @moduledoc """
  The Material context.
  """

  import Ecto.Query, warn: false
  alias Platform.Repo
  alias Platform.Projects
  require Logger
  use Memoize

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

  defp hydrate_media_query(query, opts \\ []) do
    query
    |> preload_media_versions()
    |> preload_media_updates()
    |> preload_media_project()
    |> then(fn x ->
      case Keyword.get(opts, :for_user) do
        nil -> x
        user -> apply_user_fields(x, user, opts)
      end
    end)
  end

  defp load_media_color(query) do
    # Populate the `display_color` virtual attribute.
    query
    |> join(:left, [m], m in assoc(m, :project), as: :project)
    |> select_merge([m, project: p], %{display_color: p.color})
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
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  defp _query_media(query, opts) do
    # Helper function used to abstract behavior of the `query_media` functions. Options:
    # - for_user -- populate this user's data into the response object (e.g., whether there is an unread notification, the user is subscribed, etc)
    # - limit_to_unread_notifications -- restrict to incidents with unread notifications
    # - limit_to_subscriptions -- restrict to incidents the user is subscribed to

    query
    |> then(fn q ->
      if Keyword.get(opts, :hydrate, true), do: hydrate_media_query(q, opts), else: q
    end)
    |> then(fn q ->
      if not Keyword.get(opts, :include_deleted, false) do
        q |> where([m], not m.deleted)
      else
        q
      end
    end)
    |> load_media_color()
    |> order_by(desc: :inserted_at)
    |> distinct(true)
  end

  @doc """
  Query the list of media. Will preload the versions and updates.
  """
  def query_media(query \\ Media, opts \\ []) do
    _query_media(query, opts)
    |> Repo.all()
  end

  @doc """
  Query the list of media, paginated. Will preload the versions and updates. Behavior otherwise the same as query_media/1.
  """
  def query_media_paginated(query \\ Media, opts \\ []) do
    _query_media(query, opts)
    # Fallback for null/equal values
    |> order_by(desc: :id)
    |> Repo.paginate(opts)
  end

  @doc """
  Get recently updated media, based on the most recent Update (including comments). Supports pagination via the `offset` and `limit` options.
  """
  def get_recently_updated_media_paginated(opts \\ []) do
    user = Keyword.get(opts, :restrict_to_user)
    project_id = Keyword.get(opts, :restrict_to_project_id)

    filter_user =
      if not is_nil(user) do
        dynamic([m, update: u], u.user_id == ^user.id)
      else
        true
      end

    filter_project_id =
      if not is_nil(project_id) do
        dynamic([m, update: u], m.project_id == ^project_id)
      else
        true
      end

    query =
      Media
      |> join(:left, [m], u in assoc(m, :updates), as: :update)
      |> where([m, update: u], ^filter_user)
      |> where([m, update: u], ^filter_project_id)
      |> order_by([m, update: u], desc: u.inserted_at)
      |> preload([m, update: u], updates: u)
      |> preload([m, update: u], updates: [media: [project: [:attributes]]])
      |> select_merge([m, update: u], %{last_update_time: u.inserted_at})
      |> order_by([m, update: u], desc: m.id)
      |> limit(^Keyword.get(opts, :limit, 25))
      |> offset(^Keyword.get(opts, :offset, 0))

    _query_media(query, opts)
    |> Repo.all()
  end

  @doc """
  Returns the list of media subscribed to by the given user.
  """
  def list_subscribed_media(%User{} = user) do
    user
    |> Ecto.assoc(:subscribed_media)
    |> order_by(desc: :inserted_at)
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
    query
    |> preload(updates: [:user, :media_version, :old_project, :new_project, media: [:project]])
  end

  defp preload_media_project(query) do
    query |> preload(project: [:attributes])
  end

  defp apply_user_fields(query, user, opts)

  defp apply_user_fields(query, nil, _opts) do
    query
  end

  defp apply_user_fields(media_query, %User{} = user, opts) do
    from(m in media_query,
      left_join: n in Platform.Notifications.Notification,
      as: :notification,
      on: n.media_id == m.id and n.user_id == ^user.id and not n.read,
      left_join: s in Platform.Material.MediaSubscription,
      as: :subscription,
      on: s.media_id == m.id and s.user_id == ^user.id,
      select_merge: %{
        has_unread_notification: not is_nil(n),
        has_subscription: not is_nil(s)
      },
      where: ^(not Keyword.get(opts, :limit_to_unread_notifications, false)) or not is_nil(n),
      where: ^(not Keyword.get(opts, :limit_to_subscriptions, false)) or not is_nil(s)
    )
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
      |> Media.changeset(attrs, user)

    cond do
      !changeset.valid? ->
        {:error, changeset}

      true ->
        Repo.transaction(fn ->
          changeset = change_media(%Media{}, attrs, user)

          {:ok, media} =
            changeset
            |> Repo.insert()

          {:ok, _} =
            Updates.change_from_media_creation(media, user)
            |> Updates.create_update_from_changeset()

          # Automatically tag new incidents created by regular users, if desirable
          {:ok, media} =
            with false <- Accounts.is_privileged(user),
                 new_tags_json <- System.get_env("AUTOTAG_USER_INCIDENTS"),
                 false <- is_nil(new_tags_json),
                 {:ok, new_tags} <- Jason.decode(new_tags_json) do
              {:ok, new_media} =
                update_media_attribute_audited(
                  media,
                  Attribute.get_attribute(:tags),
                  Accounts.get_auto_account(),
                  %{"attr_tags" => (media.attr_tags || []) ++ new_tags}
                )

              {:ok, new_media}
            else
              _ -> {:ok, media}
            end

          # Subscribe the creator
          {:ok, _} = subscribe_user(media, user)

          # Upload media, if provided
          for url <- Ecto.Changeset.get_field(changeset, :urls_parsed) do
            {:ok, _} =
              create_media_version_audited(media, user, %{
                upload_type: :direct,
                status: :pending,
                source_url: url,
                media_id: media.id
              })
          end

          # Schedule metadata generation
          schedule_media_auto_metadata_update(media)

          media
        end)
    end
  end

  def get_raw_slug(slug) do
    # If the slug has a prefix that is not ATL, we need to strip it off
    # and look up the media by the slug without the prefix

    case String.split(slug, "-", parts: 2) do
      [prefix, slug] when prefix != "ATL" -> slug
      _ -> slug
    end
  end

  def get_full_media_by_slug(slug) do
    Media
    |> preload_media_versions()
    |> preload_media_updates()
    |> preload_media_project()
    |> Repo.get_by(slug: get_raw_slug(slug))
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
        Updates.post_bot_comment(
          media,
          "This incident was created via **bulk import**, so some attributes are pre-filled." <>
            if(length(sources) > 0,
              do:
                "\n\nSource media for this incident is available at the following URLs, which Atlos will attempt to automatically archive:\n\n" <>
                  Enum.join(sources |> Enum.map(&("- " <> &1)), "\n"),
              else: ""
            )
        )

      # Attempt to archive all media versions
      for source <- sources do
        {:ok, version} =
          create_media_version(media, %{
            upload_type: :direct,
            status: :pending,
            source_url: source,
            media_id: media.id
          })

        archive_media_version(version, priority: 3, hide_version_on_failure: false)
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
  Soft deletes a media.
  """
  def soft_delete_media_audited(%Media{} = media, %User{} = user) do
    cs = change_media(media, %{deleted: true})

    if Accounts.is_admin(user) do
      Repo.transaction(fn ->
        with {:ok, media} <- Repo.update(cs),
             update_changeset <- Updates.change_from_media_deletion(media, user),
             {:ok, _} <- Updates.create_update_from_changeset(update_changeset) do
          media
        else
          _val ->
            {:error, cs}
        end
      end)
    else
      IO.puts("not admin")

      {:error,
       cs
       |> Ecto.Changeset.add_error(:deleted, "You cannot mark an incident as deleted.")}
    end
  end

  @doc """
  Soft deletes a media.
  """
  def soft_undelete_media_audited(%Media{} = media, %User{} = user) do
    cs = change_media(media, %{deleted: false})

    if Accounts.is_admin(user) do
      Repo.transaction(fn ->
        with {:ok, media} <- Repo.update(cs),
             update_changeset <- Updates.change_from_media_undeletion(media, user),
             {:ok, _} <- Updates.create_update_from_changeset(update_changeset) do
          media
        else
          _ -> {:error, cs}
        end
      end)
    else
      {:error,
       cs
       |> Ecto.Changeset.add_error(:deleted, "You cannot undelete an incident.")}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking media changes.

  ## Examples

      iex> change_media(media)
      %Ecto.Changeset{data: %Media{}}

  """
  def change_media(%Media{} = media, attrs \\ %{}, user \\ nil) do
    Media.changeset(media, attrs, user)
  end

  @doc """
  Returns the list of media_versions. Will preload the associated media.

  ## Examples

      iex> list_media_versions()
      [%MediaVersion{}, ...]

  """
  def list_media_versions do
    Repo.all(MediaVersion |> preload(:media))
  end

  @doc """
  Query the list of media versions, paginated. Will preload the associated media.
  """
  def query_media_versions_paginated(query \\ MediaVersion, opts \\ []) do
    applied_options = Keyword.merge([limit: 50], opts)

    query
    |> preload(:media)
    # Fallback for null/equal values
    |> order_by(desc: :id)
    |> Repo.paginate(applied_options)
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

  @doc """
  Returns the number of media versions associated with the given media ID. We don't require
  the media itself, since sometimes we don't have it loaded.
  """
  def count_media_versions_for_media_id(media_id) do
    Repo.one(
      from(v in MediaVersion,
        where: v.media_id == ^media_id,
        select: count("*")
      )
    )
  end

  def get_media_versions_by_source_url(url) do
    Repo.all(
      from(v in MediaVersion,
        where: v.source_url == ^url,
        preload: [media: [[updates: :user], :versions, project: [:attributes]]]
      )
    )
    |> Enum.sort_by(& &1.media.id)
    |> Enum.dedup_by(& &1.media.id)
  end

  def get_media_versions_by_media(%Media{} = media) do
    Repo.all(
      from(v in MediaVersion,
        where: v.media_id == ^media.id
      )
    )
  end

  def get_media_by_source_url(source_url) do
    get_media_versions_by_source_url(source_url)
    |> Enum.map(& &1.media)
    |> Enum.sort()
    |> Enum.dedup()
  end

  @doc """
  Updates the auto metadata for the given media. Auto metadata is a JSONB object
  that is automatically generated to help index and organize media. (E.g., it contains
  geocoding information used for search.)

  This is an internal action and does not use a changeset. It does not update the `updated_at`
  field on the given media.
  """
  def update_media_auto_metadata(%Media{} = media, metadata) do
    Repo.update_all(from(m in Media, where: m.id == ^media.id), set: [auto_metadata: metadata])
  end

  def create_media_version(%Media{} = media, attrs \\ %{}) do
    result =
      %MediaVersion{}
      |> MediaVersion.changeset(
        attrs
        |> Map.put("media_id", media.id)
        |> Map.put("scoped_id", count_media_versions_for_media_id(media.id) + 1)
        |> Utils.make_keys_strings()
      )
      |> Repo.insert()

    result
  end

  def create_media_version_audited(
        %Media{} = media,
        %User{} = user,
        attrs \\ %{}
      ) do
    if Media.can_user_edit(media, user) do
      Repo.transaction(fn ->
        with {:ok, version} <- create_media_version(media, attrs),
             update_changeset <-
               Updates.change_from_media_version_upload(media, user, version, attrs),
             {:ok, _} <- Updates.create_update_from_changeset(update_changeset) do
          Updates.subscribe_if_first_interaction(media, user)
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

  def change_media_project(%Media{} = media, attrs \\ %{}, user \\ nil) do
    Media.project_changeset(media, attrs, user)
  end

  def update_media_project(%Media{} = media, attrs \\ %{}, user \\ nil) do
    change_media_project(media, attrs, user)
    |> Repo.update()
  end

  def update_media_project_audited(%Media{} = media, %User{} = user, attrs \\ %{}) do
    unless Media.can_user_edit(media, user) do
      raise "No permission"
    end

    old_media = media

    res =
      Repo.transaction(fn ->
        with {:ok, media} <- update_media_project(media, attrs, user),
             update_changeset <- Updates.change_from_media_project_change(old_media, media, user),
             {:ok, _} <- Updates.create_update_from_changeset(update_changeset) do
          Updates.subscribe_if_first_interaction(media, user)
          media
        else
          _ -> {:error, change_media_project(media, attrs, user)}
        end
      end)

    # Schedule the media to have its auto-metadata regenerated
    schedule_media_auto_metadata_update(media)

    res
  end

  @doc """
  Duplicate (and re-process) the given media version to the new media.
  """
  def copy_media_version_to_new_media_audited(
        %MediaVersion{} = media_version,
        %Media{} = destination,
        %User{} = user
      ) do
    {:ok, new_version} =
      create_media_version_audited(
        destination,
        user,
        Map.merge(Map.from_struct(media_version), %{
          status: :pending,
          hashes: nil
        })
      )

    archive_media_version(new_version, clone_from: media_version.id)

    {:ok, new_version}
  end

  @doc """
  Merges the source media versions into the destination media. If a media version's URL is already present on a media version
  in the destination, it will not be copied.
  """
  def merge_media_versions_audited(%Media{} = source, %Media{} = destination, %User{} = user) do
    Repo.transaction(fn ->
      destination_urls = get_media_versions_by_media(destination) |> Enum.map(& &1.source_url)

      for version <-
            get_media_versions_by_media(source) |> Enum.filter(&(&1.visibility == :visible)) do
        if not Enum.member?(destination_urls, version.source_url) do
          {:ok, _} = copy_media_version_to_new_media_audited(version, destination, user)
        end
      end

      Updates.post_bot_comment(
        source,
        "[[@#{user.username}]] merged this incident's media into [[#{destination.slug}]]."
      )

      Updates.post_bot_comment(
        destination,
        "[[@#{user.username}]] merged [[#{source.slug}]]'s media into this incident."
      )
    end)
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
        %MediaVersion{status: :pending, id: id} = _version,
        opts \\ []
      ) do
    %{
      "media_version_id" => id,
      "hide_version_on_failure" => Keyword.get(opts, :hide_version_on_failure, false),
      "clone_from_media_version_id" => Keyword.get(opts, :clone_from, nil)
    }
    |> Platform.Workers.Archiver.new(priority: Keyword.get(opts, :priority, 1))
    |> Oban.insert!()
  end

  @doc """
  Schedules the given media to have its auto-metadata updated.

  Options:
  - priority: 0-3, the priority (default 1)
  """
  def schedule_media_auto_metadata_update(%Media{id: id} = _media, opts \\ []) do
    %{
      "media_id" => id
    }
    |> Platform.Workers.AutoMetadata.new(priority: Keyword.get(opts, :priority, 1))
    |> Oban.insert!()
  end

  @doc """
  Get a signed URL for the media version. Type can be :original or :thumb (defaults to :original).
  """
  defmemo media_version_location(version, media, type \\ :original), expires_in: 60 * 1000 do
    cond do
      is_nil(version.file_location) ->
        nil

      String.starts_with?(version.file_location, "https://") ->
        version.file_location

      true ->
        Uploads.WatermarkedMediaVersion.url({version.file_location, media}, type,
          signed: true,
          expires_in: 60 * 60 * 6
        )
    end
  end

  @doc """
  Changeset for multiple media attributes at a time. Delegates most functionality to change_media_attribute, so it also checks permissions.
  """
  def change_media_attributes(
        %Media{} = media,
        attributes,
        attrs,
        opts \\ []
      ) do
    Attribute.combined_changeset(media, attributes, attrs, opts)
  end

  @doc """
  Changeset for the media attribute. Also checks permissions.
  """
  def change_media_attribute(
        %Media{} = media,
        %Attribute{} = attribute,
        attrs \\ %{},
        opts \\ []
      ) do
    Attribute.combined_changeset(
      media,
      attribute,
      attrs,
      opts
    )
  end

  def update_media_attribute(media, %Attribute{} = attribute, attrs, user \\ nil) do
    result =
      media
      |> Attribute.changeset(attribute, attrs, user: user)
      |> Repo.update()

    invalidate_attribute_values_cache()

    result
  end

  def update_media_attributes(media, attributes, attrs, opts \\ []) do
    result =
      change_media_attributes(media, attributes, attrs, opts)
      |> Repo.update()

    invalidate_attribute_values_cache()

    result
  end

  def get_attribute_value(%Media{} = media, %Attribute{} = attr) do
    case attr.schema_field do
      :project_attributes ->
        media
        |> Map.get(:project_attributes, [])
        |> Enum.find(fn pa -> pa.id == attr.name end)
        |> case do
          nil -> nil
          %Platform.Material.Media.ProjectAttributeValue{value: value} -> value
        end

      v ->
        media
        |> Map.get(v)
    end
  end

  @doc """
  Do an audited update of the given attribute. Will broadcast change via PubSub.
  """
  def update_media_attribute_audited(media, %Attribute{} = attribute, %User{} = user, attrs) do
    update_media_attributes_audited(media, [attribute], user, attrs)
  end

  @doc """
  Do an audited update of the given attributes. Will broadcast change via PubSub.
  """
  def update_media_attributes_audited(media, attributes, %User{} = user, attrs) do
    media_changeset = change_media_attributes(media, attributes, attrs, user: user)

    update_changeset =
      Updates.change_from_attributes_changeset(media, attributes, user, media_changeset, attrs)

    # Make sure both changesets are valid
    cond do
      !(media_changeset.valid? && update_changeset.valid?) ->
        dbg(update_changeset)
        {:error, media_changeset}

      true ->
        res =
          Repo.transaction(fn ->
            {:ok, _} = Updates.create_update_from_changeset(update_changeset)
            {:ok, res} = update_media_attributes(media, attributes, attrs, user: user)
            Updates.subscribe_if_first_interaction(media, user)
            res
          end)

        # Schedule the media to have its auto-metadata regenerated
        schedule_media_auto_metadata_update(media)

        res
    end
  end

  @doc """
  Returns whether the update change attribute is combined or legacy. Prior to September 2022, update
  change values (e.g., `new` or `old`) were JSON encodings of the schema field value; now, update values
  are a dictionary of schema fields and their values. This allows us to encode changes to fields in the same
  update.
  """
  def is_combined_update_value(value) do
    with true <- is_map(value),
         true <- Map.get(value, "_combined", false) do
      true
    else
      _ -> false
    end
  end

  def get_subscription(%Media{} = media, %User{} = user) do
    Repo.get_by(MediaSubscription, media_id: media.id, user_id: user.id)
  end

  def subscribe_user(%Media{} = media, %User{} = user) do
    MediaSubscription.changeset(%MediaSubscription{}, %{media_id: media.id, user_id: user.id})
    |> Repo.insert(on_conflict: :nothing)
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

  def get_subscribers(%Media{} = media) do
    Repo.all(
      from(w in MediaSubscription,
        where: w.media_id == ^media.id,
        preload: :user
      )
    )
    |> Enum.map(& &1.user)
  end

  def total_subscribed!(%Media{} = media) do
    [count] =
      Repo.all(
        from(w in MediaSubscription,
          where: w.media_id == ^media.id,
          select: count()
        )
      )

    count
  end

  def total_media_in_project!(%Projects.Project{} = project) do
    [count] =
      Repo.all(
        from(m in Media,
          where: m.project_id == ^project.id,
          select: count()
        )
      )

    count
  end

  def media_thumbnail(%Media{} = media) do
    case Enum.find(
           media.versions |> Enum.sort_by(& &1.inserted_at) |> Enum.reverse(),
           &(!(&1.visibility != :visible or is_nil(&1.file_location)))
         ) do
      nil ->
        nil

      val ->
        if String.starts_with?(val.file_location, "https://"),
          # This allows us to have easy demo data — just give a raw HTTPS URL
          do: val.file_location,
          else:
            Uploads.WatermarkedMediaVersion.url({val.file_location, media}, :thumb,
              signed: true,
              expires_in: 60 * 60 * 6
            )
    end
  end

  def contributors(%Media{} = media) do
    Enum.uniq(
      media.updates
      |> Enum.filter(&(not &1.hidden))
      |> Enum.map(& &1.user)
    )
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

  @doc """
  Get the unique values of the given attribute across *all* media. May hit the database, but cached for 5 minutes.
  """
  defmemo get_values_of_attribute_cached(%Attribute{type: :multi_select} = attribute),
    expires_in: 300 * 1000 do
    get_values_of_attribute(attribute)
  end

  @doc """
  Invalidate the value cache for the given attribute.
  """
  def invalidate_attribute_values_cache() do
    Memoize.invalidate(__MODULE__, :get_values_of_attribute_cached)
  end

  @doc """
  Submit the given `MediaVersion` for archival by the Internet Archive, if keys are available.
  """
  def submit_for_external_archival(%MediaVersion{source_url: url} = _version) do
    Task.start(fn ->
      key = System.get_env("SPN_ARCHIVE_API_KEY")

      if is_nil(key) do
        Logger.info(
          "Not submitting #{url} for archival by the Internet Archive; no SPN archive key available."
        )
      else
        with {:ok, 200, _, _} <-
               :hackney.post(
                 "https://web.archive.org/save",
                 [{"Authorization", "LOW #{key}"}, {"Accept", "application/json"}],
                 "url=#{url |> URI.encode_www_form()}",
                 [:with_body]
               ) do
          Logger.info("Submitted #{url} for archival by the Internet Archive.")
        else
          error ->
            Logger.error("Unable to submit #{url} to the Internet Archive: " <> inspect(error))
        end
      end
    end)
  end

  @doc """
  Get the human-readable name of the media version (e.g., ABCDEF/1). The media must match the version.
  """
  def get_human_readable_media_version_name(%Media{} = media, %MediaVersion{} = version) do
    "#{media.slug}/#{version.scoped_id}"
  end

  @doc """
  Get the categorization group for the media. Currently, this is just its status.
  """
  def get_media_organization_type(%Media{} = media) do
    media.attr_status
  end

  @doc """
  Return summary statistics about the number of incidents by status.

  Optionally include `project_id` to filter to a particular project.
  """
  def status_overview_statistics(opts \\ []) do
    from(m in Media,
      where: not m.deleted,
      group_by: m.attr_status,
      select: {m.attr_status, count(m.id)}
    )
    |> then(fn query ->
      case Keyword.get(opts, :project_id) do
        nil ->
          query

        project_id ->
          from(m in query, where: m.project_id == ^project_id)
      end
    end)
    |> Repo.all()
  end
end
