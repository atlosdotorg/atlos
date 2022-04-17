defmodule Platform.Material.MediaSearch do
  use Ecto.Schema
  import Ecto.Query
  alias Platform.Material.Media

  @types %{query: :string}

  def changeset(params \\ %{}) do
    data = %{}

    {data, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.validate_length(:query, max: 256)
  end

  @doc """
  Builds a composeable query given the search changeset.
  """
  def search_query(queryable \\ Media, %Ecto.Changeset{} = cs) do
    query =
      case map_size(cs.changes) == 0 do
        true -> queryable
        false -> Media.text_search(cs.changes.query, queryable)
      end

    query
  end

  @doc """
  Filters the query results so that they are viewable to the given user
  """
  def filter_viewable(queryable \\ Media, %Platform.Accounts.User{} = user) do
    if Enum.member?(user.roles || [], :admin) do
      queryable
    else
      queryable |> where([u], ^"Hidden" not in u.attr_restrictions or is_nil(u.attr_restrictions))
    end
  end
end
