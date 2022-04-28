defmodule Platform.Material.MediaSearch do
  use Ecto.Schema
  import Ecto.Query
  alias Platform.Material.Media

  # Search components:
  #   - Query (string)
  #   - Date
  #   - Flag
  #   - Sort by
  @types %{query: :string, sort: :string}

  def changeset(params \\ %{}) do
    data = %{}

    {data, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.validate_length(:query, max: 256)
    |> Ecto.Changeset.validate_inclusion(:sort, [
      :date_desc,
      :date_asc,
      :modified_desc,
      :modified_asc
    ])
  end

  defp apply_query_component(queryable, changeset, :query) do
    case Map.get(changeset.changes, :query) do
      nil -> queryable
      query -> Media.text_search(query, queryable)
    end
  end

  @doc """
  Builds a composeable query given the search changeset.
  """
  def search_query(queryable \\ Media, %Ecto.Changeset{} = cs) do
    queryable
    |> apply_query_component(cs, :query)
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
