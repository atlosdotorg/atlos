defmodule Platform.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
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
  def get_notification!(id), do: Repo.get!(Notification |> preload([:update]), id)

  @doc """
  Gets all the notifications for a user.
  """
  def get_notifications_by_user(%User{} = user) do
    Repo.all(from n in Notification, where: n.user_id == ^user.id, preload: [:update])
  end

  @doc """
  Returns whether the user has any unread notifications.
  """
  def has_unread_notifications(%User{} = user) do
    Repo.exists?(from n in Notification, where: n.user_id == ^user.id and n.read == false)
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
    recipients =
      recipients ++
        (Regex.scan(Platform.Utils.get_tag_regex(), update.explanation || "")
         |> Enum.map(&List.last(&1))
         |> Enum.map(&Accounts.get_user_by_username(&1))
         |> Enum.filter(&(!is_nil(&1))))

    # Deduplicate and remove source user
    recipients =
      recipients |> Enum.sort() |> Enum.dedup() |> Enum.filter(&(&1.id != update.user_id))

    # Post the notifications
    Enum.map(
      recipients |> dbg(),
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
end
