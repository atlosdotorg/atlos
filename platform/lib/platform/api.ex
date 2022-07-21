defmodule Platform.API do
  @moduledoc """
  The API context.
  """

  import Ecto.Query, warn: false
  alias Platform.Repo

  alias Platform.API.APIToken

  @doc """
  Returns the list of api_tokens.

  ## Examples

      iex> list_api_tokens()
      [%APIToken{}, ...]

  """
  def list_api_tokens do
    Repo.all(APIToken)
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
  Creates a api_token.

  ## Examples

      iex> create_api_token(%{field: value})
      {:ok, %APIToken{}}

      iex> create_api_token(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_api_token(attrs \\ %{}) do
    %APIToken{}
    |> APIToken.changeset(attrs)
    |> Repo.insert()
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
  Returns an `%Ecto.Changeset{}` for tracking api_token changes.

  ## Examples

      iex> change_api_token(api_token)
      %Ecto.Changeset{data: %APIToken{}}

  """
  def change_api_token(%APIToken{} = api_token, attrs \\ %{}) do
    APIToken.changeset(api_token, attrs)
  end
end
