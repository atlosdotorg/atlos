defmodule Platform.Updates do
  @moduledoc """
  The Updates context.
  """

  import Ecto.Query, warn: false
  alias Platform.Repo

  alias Platform.Updates.Update
  alias Platform.Material.Attribute
  alias Platform.Material.Media
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
  Gets a single update.

  Raises `Ecto.NoResultsError` if the Update does not exist.

  ## Examples

      iex> get_update!(123)
      %Update{}

      iex> get_update!(456)
      ** (Ecto.NoResultsError)

  """
  def get_update!(id), do: Repo.get!(Update, id)

  @doc """
  Creates a update.

  ## Examples

      iex> create_update(%{field: value})
      {:ok, %Update{}}

      iex> create_update(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_update(attrs \\ %{}) do
    %Update{}
    |> Update.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a update.

  ## Examples

      iex> update_update(update, %{field: new_value})
      {:ok, %Update{}}

      iex> update_update(update, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_update(%Update{} = update, attrs) do
    update
    |> Update.changeset(attrs)
    |> Repo.update()
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
  def change_update(%Update{} = update, attrs \\ %{}) do
    Update.changeset(update, attrs)
  end

  def change_from_attribute_changeset(%Media{} = media, %Attribute{} = attribute, %User{} = user, attrs) do
    old_value = Map.get(media, attribute.schema_field) |> Jason.encode!()
    new_value = Map.get(attrs, Atom.to_string(attribute.schema_field)) |> Jason.encode!()

    change_update(%Update{}, attrs
      |> Map.put("old_value", old_value)
      |> Map.put("new_value", new_value)
      |> Map.put("media_id", media.id)
      |> Map.put("user_id", user.id)
      |> Map.put("modified_attribute", attribute.name)
      |> Map.put("type", :update_attribute)
    )
  end

  def change_from_media_creation(%Media{} = media, %User{} = user) do
    change_update(%Update{}, %{
      "user_id" => user.id,
      "type" => :create,
      "media_id" => media.id,
    })
  end

  @doc """
  Get the updates associated with the given media.
  """
  def get_updates_for_media(media) do
    Repo.all(from u in Update, where: u.media_id == ^media.id, preload: :user, preload: :media, order_by: u.inserted_at) # TODO: remove n+1
  end
end
