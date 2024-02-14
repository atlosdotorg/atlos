defmodule Platform.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias PlatformWeb.Router
  alias Platform.Accounts.UserNotifier
  alias Platform.Permissions
  alias Platform.Repo

  alias Platform.Accounts.User
  alias Platform.Updates.Update
  alias Platform.Material
  alias Platform.Notifications.Notification
  alias Platform.Accounts

  @doc """
  Returns the list of notifications.

  ## Examples

      iex> list_notifications()
      [%Notification{}, ...]

  """
  def list_notifications do
    Repo.all(Notification)
  end

  @doc """
  Gets a single notification.

  Raises `Ecto.NoResultsError` if the Notification does not exist.

  ## Examples

      iex> get_notification!(123)
      %Notification{}

      iex> get_notification!(456)
      ** (Ecto.NoResultsError)

  """
  def get_notification!(id),
    do:
      Repo.get!(
        Notification |> preload(update: [:user, media: [:project]]),
        id
      )

  @doc """
  Gets all the notifications for a user.
  """
  def get_notifications_by_user_paginated(%User{} = user, options \\ []) do
    query =
      from(n in Notification,
        where: n.user_id == ^user.id,
        left_join: u in assoc(n, :update),
        preload: [
          update: [
            :user,
            :media_version,
            :api_token,
            media: [project: [memberships: [:user]]]
          ]
        ]
      )

    # Apply the filter option
    query =
      case Keyword.get(options, :filter, "all") do
        "unread" ->
          query |> where([n, _], n.read == false)

        # tags: update explanation contains [[@user.username]]
        "tags" ->
          filter = "%[[@" <> user.username <> "]]%"

          query
          |> where([_, u], fragment("? ILIKE ?", u.explanation, ^filter))

        _ ->
          query
      end

    # Apply the sort option
    query =
      case Keyword.get(options, :sort, "newest") do
        "oldest" -> query |> order_by(asc: :inserted_at)
        _ -> query |> order_by(desc: :inserted_at)
      end

    # Apply the query option
    query =
      case Keyword.get(options, :query, "") do
        "" ->
          query

        q ->
          query
          |> where(
            [n, u],
            fragment(
              "? @@ websearch_to_tsquery('simple', ?) or ? @@ websearch_to_tsquery('simple', ?)",
              n.searchable,
              ^q,
              u.searchable,
              ^q
            )
          )
      end

    Repo.paginate(query, options)
  end

  @doc """
  Returns whether the user has any unread notifications.
  """
  def has_unread_notifications(%User{} = user) do
    Repo.exists?(from n in Notification, where: n.user_id == ^user.id and n.read == false)
  end

  def mark_notifications_as_read(%User{} = user, media \\ nil) do
    base = from(n in Notification, where: n.user_id == ^user.id)
    base = if media, do: base |> where([n], n.media_id == ^media.id), else: base
    Repo.update_all(base, set: [read: true])
  end

  @doc """
  Creates a notification.

  ## Examples

      iex> create_notification(%{field: value})
      {:ok, %Notification{}}

      iex> create_notification(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  def create_notifications_from_update(%Update{} = update) do
    recipients = []

    # Add people who are subscribed to the relevant media
    recipients = recipients ++ Material.get_subscribers(Material.get_media!(update.media_id))

    # Add people who are tagged
    media = Material.get_media!(update.media_id)

    tagged_users =
      Regex.scan(Platform.Utils.get_tag_regex(), update.explanation || "")
      |> Enum.map(&List.last(&1))
      |> Enum.map(&Accounts.get_user_by_username(&1))
      |> Enum.reject(&is_nil/1)
      # Ensure all tagged users are a member of the project and can view the media
      |> Enum.filter(fn user ->
        Permissions.can_view_media?(user, media)
      end)

    # Send email notifications to tagged users
    if not is_nil(update.user_id) do
      tagger = Accounts.get_user(update.user_id)

      Task.start(fn ->
        Enum.each(tagged_users, fn user ->
          UserNotifier.deliver_tag_notification(
            user,
            tagger,
            media,
            Router.Helpers.media_show_url(PlatformWeb.Endpoint, :show, media.slug) <>
              "#update-#{update.id}"
          )
        end)
      end)
    end

    recipients =
      recipients ++
        tagged_users

    # Add people who are newly assigned or newly removed
    recipients =
      recipients ++
        with "assignments" <- update.modified_attribute,
             attr <- Platform.Material.Attribute.get_attribute(:assignments),
             {:ok, old_value_map} <- update.old_value |> Jason.decode(),
             old_value <- Map.get(old_value_map, Platform.Updates.key_for_attribute(attr)),
             {:ok, new_value_map} <- update.new_value |> Jason.decode(),
             new_value <- Map.get(new_value_map, Platform.Updates.key_for_attribute(attr)) do
          added_members = MapSet.difference(MapSet.new(new_value), MapSet.new(old_value))

          removed_members = MapSet.difference(MapSet.new(old_value), MapSet.new(new_value))

          MapSet.union(added_members, removed_members) |> Enum.map(&Accounts.get_user!(&1))
        else
          _ -> []
        end

    # Deduplicate and remove source user
    recipients = recipients |> Enum.uniq_by(& &1.id) |> Enum.filter(&(&1.id != update.user_id))

    # Post the notifications
    Enum.map(
      recipients,
      &create_notification(%{
        type: :update,
        user_id: &1.id,
        media_id: update.media_id,
        update_id: update.id
      })
    )
  end

  @doc """
  Updates a notification.

  ## Examples

      iex> update_notification(notification, %{field: new_value})
      {:ok, %Notification{}}

      iex> update_notification(notification, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_notification(%Notification{} = notification, attrs) do
    notification
    |> Notification.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a notification.

  ## Examples

      iex> delete_notification(notification)
      {:ok, %Notification{}}

      iex> delete_notification(notification)
      {:error, %Ecto.Changeset{}}

  """
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking notification changes.

  ## Examples

      iex> change_notification(notification)
      %Ecto.Changeset{data: %Notification{}}

  """
  def change_notification(%Notification{} = notification, attrs \\ %{}) do
    Notification.changeset(notification, attrs)
  end

  @doc """
  Create a notification with the given message.
  """
  def send_message_notification_to_user(%User{} = user, message) do
    create_notification(%{content: message, type: :message, user_id: user.id})
  end

  def send_message_notification_to_all_users(message) do
    Task.start(fn ->
      Accounts.get_all_users()
      |> Enum.map(fn user ->
        create_notification(%{content: message, type: :message, user_id: user.id})
      end)
    end)
  end
end
