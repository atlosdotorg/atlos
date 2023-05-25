defmodule Platform.Updates do
  @moduledoc """
  The Updates context.
  """

  import Ecto.Query, warn: false
  alias Platform.Material.Attribute
  alias Platform.Repo

  alias Platform.Utils
  alias Platform.Updates.Update
  alias Platform.Material.Media
  alias Platform.Material.MediaVersion
  alias Platform.Accounts.User
  alias Platform.Material
  alias Platform.Accounts
  alias Platform.Permissions

  @doc """
  Returns the list of updates.

  ## Examples

      iex> list_updates()
      [%Update{}, ...]

  """
  def list_updates(opts \\ []) do
    query = Update |> preload_fields()

    query =
      if Keyword.get(opts, :inserted_after) do
        query |> where([u], u.inserted_at > ^opts[:inserted_after])
      else
        query
      end

    Repo.all(query)
  end

  defp preload_fields(queryable) do
    queryable |> preload([:user, :media_version, :old_project, :new_project, media: [:project]])
  end

  @doc """
  Create a text search query for updates, to be passed to query_updates_paginated/2.
  """
  def text_search(search_terms, queryable \\ Update) do
    if !is_nil(search_terms) and String.length(search_terms) > 0 do
      Utils.text_search(search_terms, queryable)
    else
      queryable
    end
  end

  @doc """
  Query the updates, paginated. Preloads user, media, and media_version.
  """
  def query_updates_paginated(query \\ Update, opts \\ []) do
    applied_options = Keyword.merge([limit: 50], opts)

    query
    |> preload_fields()
    |> order_by(desc: :inserted_at)
    # Fallback for null/equal values
    |> order_by(desc: :id)
    |> Repo.paginate(applied_options)
  end

  @doc """
  Gets a single update. Preloads user, media, and media_version.

  Raises `Ecto.NoResultsError` if the Update does not exist.

  ## Examples

      iex> get_update!(123)
      %Update{}

      iex> get_update!(456)
      ** (Ecto.NoResultsError)

  """
  def get_update!(id), do: Repo.get!(Update |> preload_fields(), id)

  @doc """
  Insert the given Update changeset. Helpful to use in conjunction with the dynamic changeset
  generation functions (e.g., `change_from_attribute_changeset`). Will also generate notifications.
  """
  def create_update_from_changeset(%Ecto.Changeset{data: %Update{} = _} = changeset) do
    res = changeset |> Repo.insert()

    case res do
      {:ok, update} ->
        Platform.Notifications.create_notifications_from_update(update)
        Material.broadcast_media_updated(update.media_id)

      _ ->
        nil
    end

    res
  end

  @doc """
  Update the given update using the changeset.
  """
  def update_update_from_changeset(%Ecto.Changeset{data: %Update{} = _} = changeset) do
    changeset |> Repo.update()
  end

  @doc """
  Deletes a update.

  ## Examples

      iex> delete_update(update)
      {:ok, %Update{}}

      iex> delete_update(update)
      {:error, %Ecto.Changeset{}}

  """
  def delete_update(%Update{} = update) do
    Repo.delete(update)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking update changes.

  ## Examples

      iex> change_update(update)
      %Ecto.Changeset{data: %Update{}}

  """
  def change_update(%Update{} = update, %Media{} = media, %User{} = user, attrs \\ %{}) do
    Update.changeset(update, attrs, user, media)
  end

  @doc """
  Returns the key under which the value of the attribute will be stored in change JSON records (old value, new value, etc.)
  """
  def key_for_attribute(%Attribute{} = attr) do
    cond do
      attr.schema_field == :project_attributes ->
        attr.name

      true ->
        attr.schema_field |> to_string()
    end
  end

  def value_for_attribute(%Attribute{} = attr, %Ecto.Changeset{} = changeset) do
    cond do
      attr.schema_field == :project_attributes ->
        Ecto.Changeset.get_field(changeset, :project_attributes)
        |> Enum.find(%{value: nil}, &(&1.id == attr.name))
        |> Map.get(:value)

      true ->
        Ecto.Changeset.get_field(changeset, attr.schema_field)
    end
  end

  def value_for_attribute(%Attribute{} = attr, %Media{} = media) do
    cond do
      attr.schema_field == :project_attributes ->
        Map.get(media, :project_attributes, [])
        |> Enum.find(%{value: nil}, &(&1.id == attr.name))
        |> Map.get(:value)

      true ->
        Map.get(media, attr.schema_field)
    end
  end

  @doc """
  Helper API function that takes attributes change information and uses it to create an Update changeset. Requires 'explanation' to be in attrs. The change is recorded as belonging to the head of `attributes`; all other attributes should be children of the first element.
  """
  def change_from_attributes_changeset(
        %Media{} = media,
        attributes,
        %User{} = user,
        changeset,
        attrs \\ %{}
      ) do
    # We add the _combined field so that it's unambiguous when a dict represents a collection of schema fields changing
    old_value =
      attributes
      |> Enum.map(&{key_for_attribute(&1), value_for_attribute(&1, media)})
      |> Map.new()
      |> Map.put("_combined", true)
      |> Jason.encode!()

    new_value =
      attributes
      |> Enum.map(&{key_for_attribute(&1), value_for_attribute(&1, changeset)})
      |> Map.new()
      |> Map.put("_combined", true)
      |> Jason.encode!()

    change_update(
      %Update{},
      media,
      user,
      attrs
      |> Map.put("old_value", old_value)
      |> Map.put("new_value", new_value)
      |> Map.put("modified_attribute", hd(attributes).name |> to_string())
      |> Map.put("type", :update_attribute)
    )
  end

  @doc """
  Helper API function that takes comment information and uses it to create an Update changeset. Requires 'explanation' to be in attrs.
  """
  def change_from_comment(%Media{} = media, %User{} = user, attrs \\ %{}) do
    change_update(
      %Update{},
      media,
      user,
      attrs
      |> Map.put("type", :comment)
    )
    |> Ecto.Changeset.validate_required([:explanation], message: "A comment is required to post")
    |> Ecto.Changeset.validate_length(:explanation, min: 1, max: 10000)
  end

  @doc """
  Helper API function that takes attribute change information and uses it to create an Update changeset. Requires 'explanation' to be in attrs.
  """
  def change_from_media_creation(%Media{} = media, %User{} = user) do
    change_update(
      %Update{},
      media,
      user,
      %{
        "type" => :create
      }
    )
  end

  @doc """
  Helper API function that takes attribute change information and uses it to create an Update changeset.
  """
  def change_from_media_deletion(%Media{} = media, %User{} = user) do
    change_update(
      %Update{},
      media,
      user,
      %{
        "type" => :delete
      }
    )
  end

  @doc """
  Helper API function that takes attribute change information and uses it to create an Update changeset.
  """
  def change_from_media_undeletion(%Media{} = media, %User{} = user) do
    change_update(
      %Update{},
      media,
      user,
      %{
        "type" => :undelete
      }
    )
  end

  @doc """
  Helper API function that takes attribute change information and uses it to create an Update changeset.
  """
  def change_from_media_version_upload(
        %Media{} = media,
        %User{} = user,
        %MediaVersion{} = version,
        attrs
      ) do
    change_update(
      %Update{},
      media,
      user,
      %{
        "type" => :upload_version,
        "media_version_id" => version.id,
        "explanation" => Map.get(attrs, "explanation")
      }
    )
  end

  def change_from_media_project_change(
        %Media{} = old_media,
        %Media{} = new_media,
        %User{} = user
      ) do
    old_project = old_media.project_id
    new_project = new_media.project_id

    change_update(
      %Update{},
      new_media,
      user,
      case {old_project, new_project} do
        {nil, id} when not is_nil(id) ->
          %{
            "type" => :add_project,
            "new_project_id" => id
          }

        {id, nil} when not is_nil(id) ->
          %{
            "type" => :remove_project,
            "old_project_id" => id
          }

        {old_id, new_id} when not is_nil(old_id) and not is_nil(new_id) ->
          %{
            "type" => :change_project,
            "old_project_id" => old_id,
            "new_project_id" => new_id
          }
      end
    )
  end

  @doc """
  Get the non-hidden updates associated with the given media.
  """
  def get_updates_for_media(media, exclude_hidden \\ false) do
    query =
      from(u in Update,
        where: u.media_id == ^media.id,
        order_by: [asc: u.inserted_at]
      )
      |> preload_fields()

    Repo.all(if exclude_hidden, do: query |> where([u], not u.hidden), else: query)
  end

  @doc """
  Get the updates associated with the given user.

  Options:
  - limit: maximum number of updates to return
  - exclude_hidden: whether to exclude updates marked as hidden
  """
  def get_updates_by_user(user, opts) do
    query =
      from(u in Update,
        where: u.user_id == ^user.id,
        order_by: [desc: u.inserted_at],
        limit: ^Keyword.get(opts, :limit, nil)
      )
      |> preload_fields()

    Repo.all(
      if Keyword.get(opts, :exclude_hidden, false),
        do: query |> where([u], not u.hidden),
        else: query
    )
  end

  @doc """
  Gets most recent update for the given user, associated with media that is part of the optional provided project.

  Options:
  - %Project{} = project
  """
  def most_recent_update_by_user(%User{} = user, opts \\ []) do
    query =
      from(u in Update,
        where: u.user_id == ^user.id,
        join: m in assoc(u, :media),
        order_by: [desc: u.inserted_at],
        limit: 1
      )
      |> preload_fields()

    query =
      case Keyword.get(opts, :project) do
        nil -> query
        project -> query |> where([_u, m], m.project_id == ^project.id)
      end

    Repo.one(query)
  end

  @doc """
  Gets the total number of updates by the given user over the past year.
  Optionally filterable to a particular project.
  """
  def total_updates_by_user_over_time(%User{} = user, opts \\ []) do
    query =
      from(u in Update,
        where: u.user_id == ^user.id,
        join: m in assoc(u, :media),
        where: u.inserted_at >= fragment("now() - interval '1 year'")
      )

    query =
      case Keyword.get(opts, :project) do
        nil -> query
        project -> query |> where([_u, m], m.project_id == ^project.id)
      end

    data =
      query
      |> group_by([u], [fragment("date_trunc('day', ?)", u.inserted_at)])
      |> select([u], %{date: fragment("date_trunc('day', ?)", u.inserted_at), count: count(u.id)})
      |> order_by([u], asc: fragment("date_trunc('day', ?)", u.inserted_at))
      |> Repo.all()

    # Fill in all other dates in the past year as zeroes
    now = DateTime.utc_now()
    dates = Enum.map(0..365, fn date -> DateTime.add(now, -date, :day) end)

    Enum.reduce(dates, data, fn date, data ->
      if Enum.any?(data, fn d -> d.date == date end) do
        data
      else
        [%{date: date, count: 0} | data]
      end
    end)
  end

  @doc """
  Change the visibility (per the `hidden` field) of the given media.
  """
  def change_update_visibility(%Update{} = update, hidden) do
    Update.raw_changeset(update, %{hidden: hidden}, cast_sensitive_data: true)
  end

  @doc """
  Optimistically subscribe the given user to the media if the user has no
  interactions with the media yet.
  """
  def subscribe_if_first_interaction(%Media{} = media, %User{} = user) do
    if is_list(media.updates) and
         Enum.empty?(media.updates |> Enum.filter(&(&1.user_id == user.id))) do
      Material.subscribe_user(media, user)
    else
      :no_action
    end
  end

  @doc """
  Helper function to easily post comments from the bot account.
  """
  def post_bot_comment(%Media{} = media, message) do
    bot_account = Accounts.get_auto_account()

    change_from_comment(media, bot_account, %{
      "explanation" => message
    })
    |> create_update_from_changeset()
  end
end
