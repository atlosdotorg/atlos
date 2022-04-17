defmodule Platform.Updates do
  @moduledoc """
  The Updates context.
  """

  import Ecto.Query, warn: false
  alias Platform.Repo

  alias Platform.Updates.Update
  alias Platform.Material.Attribute
  alias Platform.Material.Media
  alias Platform.Material.MediaVersion
  alias Platform.Accounts.User

  @doc """
  Returns the list of updates.

  ## Examples

      iex> list_updates()
      [%Update{}, ...]

  """
  def list_updates do
    Repo.all(Update)
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
  def get_update!(id), do: Repo.get!(Update |> preload([:user, :media, :media_version]), id)

  @doc """
  Insert the given Update changeset. Helpful to use in conjunction with the dynamic changeset
  generation functions (e.g., `change_from_attribute_changeset`).
  """
  def create_update_from_changeset(%Ecto.Changeset{data: %Update{} = _} = changeset) do
    changeset |> Repo.insert()
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
  Helper API function that takes attribute change information and uses it to create an Update changeset. Requires 'explanation' to be in attrs.
  """
  def change_from_attribute_changeset(
        %Media{} = media,
        %Attribute{} = attribute,
        %User{} = user,
        changeset,
        attrs \\ %{}
      ) do
    old_value = Map.get(media, attribute.schema_field) |> Jason.encode!()
    new_value = Map.get(changeset.changes, attribute.schema_field) |> Jason.encode!()

    change_update(
      %Update{},
      media,
      user,
      attrs
      |> Map.put("old_value", old_value)
      |> Map.put("new_value", new_value)
      |> Map.put("modified_attribute", attribute.name)
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
  Helper API function that takes attribute change information and uses it to create an Update changeset. Requires 'explanation' to be in attrs.
  """
  def change_from_media_version_upload(
        %Media{} = media,
        %User{} = user,
        %MediaVersion{} = version
      ) do
    change_update(
      %Update{},
      media,
      user,
      %{
        "type" => :upload_version,
        "media_version_id" => version.id
      }
    )
  end

  @doc """
  Get the non-hidden updates associated with the given media.
  """
  def get_updates_for_media(media, exclude_hidden \\ false) do
    query =
      from u in Update,
        where: u.media_id == ^media.id,
        preload: [:user, :media, :media_version],
        order_by: [asc: u.inserted_at]

    Repo.all(if exclude_hidden, do: query |> where([u], not u.hidden), else: query)
  end

  @doc """
  Get the non-hidden updates associated with the given user.
  """
  def get_updates_for_user(user, exclude_hidden \\ false) do
    query =
      from u in Update,
        where: u.user_id == ^user.id,
        preload: [:user, :media, :media_version],
        order_by: [asc: u.inserted_at]

    Repo.all(if exclude_hidden, do: query |> where([u], not u.hidden), else: query)
  end

  @doc """
  Change the visibility (per the `hidden` field) of the given media.
  """
  def change_update_visibility(%Update{} = update, hidden) do
    Update.raw_changeset(update, %{hidden: hidden})
  end

  @doc """
  Is the given user able to view the given update?
  """
  def can_user_view(%Update{} = update, %User{} = user) do
    case update.hidden do
      true -> Platform.Accounts.is_admin(user)
      false -> true
    end
  end
end
