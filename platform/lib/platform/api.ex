defmodule Platform.API do
  @moduledoc """
  The API context.
  """

  import Ecto.Query, warn: false
  alias Platform.Repo

  alias Platform.API.APIToken
  alias Platform.Projects.Project

  @doc """
  Returns the list of api_tokens.

  ## Examples

      iex> list_api_tokens()
      [%APIToken{}, ...]

  """
  def list_api_tokens do
    Repo.all(from(a in APIToken, preload: [:project, :creator]))
  end

  @doc """
  Returns the list of api_tokens for a given project.

  ## Examples

      iex> list_api_tokens_for_project(project)
      [%APIToken{}, ...]

  """
  def list_api_tokens_for_project(%Project{} = project) do
    Repo.all(from(a in APIToken, where: a.project_id == ^project.id, preload: [:project, :creator]))
  end

  @doc """
  Gets a single api_token.

  Raises `Ecto.NoResultsError` if the Api token does not exist.

  ## Examples

      iex> get_api_token!(123)
      %APIToken{}

      iex> get_api_token!(456)
      ** (Ecto.NoResultsError)

  """
  def get_api_token!(id), do: Repo.get!(APIToken, id)

  @doc """
  Gets a single api_token by its value.
  """
  def get_api_token_by_value(value), do: Repo.get_by(APIToken, value: value)

  @doc """
  Creates a api_token.

  ## Examples

      iex> create_api_token(%{field: value})
      {:ok, %APIToken{}}

      iex> create_api_token(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_api_token(attrs \\ %{}, opts \\ []) do
    changeset =
      %APIToken{}
      |> APIToken.changeset(attrs)

    changeset =
      if Keyword.get(opts, :project) do
        Ecto.Changeset.put_change(changeset, :project_id, Keyword.get(opts, :project).id)
      else
        changeset
      end

    changeset =
      if Keyword.get(opts, :creator) do
        Ecto.Changeset.put_change(changeset, :creator_id, Keyword.get(opts, :creator).id)
      else
        changeset
      end

    changeset =
      Ecto.Changeset.put_change(changeset, :is_legacy, Keyword.get(opts, :legacy, false))

    changeset
    |> Repo.insert()
  end

  @doc """
  Marks an API token as used. This is used to track the last time an API token was used.

  ## Examples

      iex> mark_api_token_used(api_token)
      {:ok, %APIToken{}}

      iex> mark_api_token_used(api_token)
      {:error, %Ecto.Changeset{}}
  """
  def mark_api_token_used(%APIToken{} = api_token) do
    # If the `last_used` date is today, then we don't need to update it.
    if api_token.last_used != Date.utc_today() do
      api_token
      |> APIToken.changeset(%{last_used: Date.utc_today()})
      |> Repo.update()
    else
      {:ok, api_token}
    end
  end

  @doc """
  Updates a api_token.

  ## Examples

      iex> update_api_token(api_token, %{field: new_value})
      {:ok, %APIToken{}}

      iex> update_api_token(api_token, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_api_token(%APIToken{} = api_token, attrs) do
    api_token
    |> APIToken.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a api_token.

  ## Examples

      iex> delete_api_token(api_token)
      {:ok, %APIToken{}}

      iex> delete_api_token(api_token)
      {:error, %Ecto.Changeset{}}

  """
  def delete_api_token(%APIToken{} = api_token) do
    Repo.delete(api_token)
  end

  @doc """
  Deactivates an API token.

  ## Examples

      iex> deactivate_api_token(api_token)
      {:ok, %APIToken{}}

      iex> deactivate_api_token(api_token)
      {:error, %Ecto.Changeset{}}
  """
  def deactivate_api_token(%APIToken{} = api_token) do
    api_token
    |> APIToken.changeset(%{is_active: false})
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking api_token changes.

  ## Examples

      iex> change_api_token(api_token)
      %Ecto.Changeset{data: %APIToken{}}

  """
  def change_api_token(%APIToken{} = api_token, attrs \\ %{}) do
    APIToken.changeset(api_token, attrs)
  end
end
