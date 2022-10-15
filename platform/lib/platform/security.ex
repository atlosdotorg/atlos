defmodule Platform.Security do
  @moduledoc """
  The Security context.
  """

  import Ecto.Query, warn: false
  alias Platform.Repo
  use Memoize

  alias Platform.Security.SecurityMode

  @doc """
  Returns the list of security_modes.

  ## Examples

      iex> list_security_modes()
      [%SecurityMode{}, ...]

  """
  def list_security_modes do
    Repo.all(SecurityMode |> preload(:user) |> order_by(desc: :id))
  end

  defp clear_cache(passthrough \\ nil) do
    Memoize.invalidate(Platform.Security)
    passthrough
  end

  defmemo get_current_state(), expires_in: 60 * 1000 do
    Repo.one(
      from x in Platform.Security.SecurityMode,
        order_by: [desc: x.id],
        limit: 1
    )
  end

  @doc """
  Gets the current security mode state.

  ## Examples

      iex> get_security_mode_state()
      :normal
  """
  def get_security_mode_state do
    case get_current_state() do
      nil -> :normal
      value -> value.mode
    end
  end

  @doc """
  Gets the current security mode state.

  ## Examples

      iex> get_security_mode_state()
      :normal
  """
  def get_security_mode_description do
    case get_current_state() do
      nil -> ""
      value -> value.description
    end
  end

  @doc """
  Gets a single security_mode.

  Raises `Ecto.NoResultsError` if the Security mode does not exist.

  ## Examples

      iex> get_security_mode!(123)
      %SecurityMode{}

      iex> get_security_mode!(456)
      ** (Ecto.NoResultsError)

  """
  def get_security_mode!(id), do: Repo.get!(SecurityMode, id)

  @doc """
  Creates a security_mode.

  ## Examples

      iex> create_security_mode(%{field: value})
      {:ok, %SecurityMode{}}

      iex> create_security_mode(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_security_mode(attrs \\ %{}) do
    %SecurityMode{}
    |> SecurityMode.changeset(attrs)
    |> Repo.insert()
    |> clear_cache()
  end

  @doc """
  Updates a security_mode.

  ## Examples

      iex> update_security_mode(security_mode, %{field: new_value})
      {:ok, %SecurityMode{}}

      iex> update_security_mode(security_mode, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_security_mode(%SecurityMode{} = security_mode, attrs) do
    security_mode
    |> SecurityMode.changeset(attrs)
    |> Repo.update()
    |> clear_cache()
  end

  @doc """
  Deletes a security_mode.

  ## Examples

      iex> delete_security_mode(security_mode)
      {:ok, %SecurityMode{}}

      iex> delete_security_mode(security_mode)
      {:error, %Ecto.Changeset{}}

  """
  def delete_security_mode(%SecurityMode{} = security_mode) do
    Repo.delete(security_mode)
    |> clear_cache()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking security_mode changes.

  ## Examples

      iex> change_security_mode(security_mode)
      %Ecto.Changeset{data: %SecurityMode{}}

  """
  def change_security_mode(%SecurityMode{} = security_mode, attrs \\ %{}) do
    SecurityMode.changeset(security_mode, attrs)
    |> clear_cache()
  end
end
