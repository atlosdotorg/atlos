defmodule Platform.Material.MediaSearch do
  use Ecto.Schema
  import Ecto.Query
  alias Platform.Material.Media

  # Search components:
  #   - Query (string)
  #   - Date
  #   - Status
  #   - Sort by
  @types %{query: :string, sort: :string, attr_status: :string, no_media_versions: :boolean}

  def changeset(params \\ %{}) do
    data = %{}

    {data, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.validate_length(:query, max: 256)
    |> Ecto.Changeset.validate_inclusion(:sort, [
      "uploaded_desc",
      "uploaded_asc",
      "modified_desc",
      "modified_asc"
    ])
  end

  defp apply_query_component(queryable, changeset, :query) do
    case Map.get(changeset.changes, :query) do
      nil -> queryable
      query -> Media.text_search(query, queryable)
    end
  end

  defp apply_query_component(queryable, changeset, :attr_status) do
    case Map.get(changeset.changes, :attr_status) do
      nil -> queryable
      "Any" -> queryable
      query -> where(queryable, [m], m.attr_status == ^query)
    end
  end

  defp apply_query_component(queryable, changeset, :no_media_versions) do
    case Map.get(changeset.changes, :no_media_versions, nil) do
      nil ->
        queryable

      false ->
        where(
          queryable,
          [u],
          fragment("EXISTS (SELECT * FROM media_versions other WHERE other.media_id = ?)", u.id)
        )

      true ->
        where(
          queryable,
          [u],
          fragment(
            "NOT EXISTS (SELECT * FROM media_versions other WHERE other.media_id = ?)",
            u.id
          )
        )
    end
  end

  defp apply_sort(queryable, changeset) do
    # Returns a {queryable, pagination_opts} tuple.

    case Map.get(changeset.changes, :sort) do
      nil ->
        {queryable, []}

      query ->
        case query do
          "uploaded_desc" ->
            {queryable |> Ecto.Query.order_by([i], desc: i.inserted_at),
             [cursor_fields: [{:inserted_at, :desc}]]}

          "uploaded_asc" ->
            {queryable |> Ecto.Query.order_by([i], asc: i.inserted_at),
             [cursor_fields: [{:inserted_at, :asc}]]}

          "modified_desc" ->
            {queryable |> Ecto.Query.order_by([i], desc: i.updated_at),
             [cursor_fields: [{:updated_at, :desc}]]}

          "modified_asc" ->
            {queryable |> Ecto.Query.order_by([i], asc: i.updated_at),
             [cursor_fields: [{:updated_at, :asc}]]}
        end
    end
  end

  @doc """
  Builds a composeable query given the search changeset. Returns a {queryable, pagination_opts} tuple.
  """
  def search_query(queryable \\ Media, %Ecto.Changeset{} = cs) do
    queryable
    |> apply_query_component(cs, :query)
    |> apply_query_component(cs, :attr_status)
    |> apply_query_component(cs, :no_media_versions)
    |> apply_sort(cs)
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
