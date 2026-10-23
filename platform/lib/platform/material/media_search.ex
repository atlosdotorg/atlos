defmodule Platform.Material.MediaSearch do
  use Ecto.Schema
  import Ecto.Query
  alias Ecto.UUID
  alias Platform.Material.Media

  # Search components:
  #   - Query (string)
  #   - Date
  #   - Status
  #   - Sort by
  #   - Display (used by views)
  @types %{
    query: :string,
    sort: :string,
    attr_status: {:array, :string},
    attr_tags: {:array, :string},
    attr_sensitive: {:array, :string},
    attr_date_min: :date,
    attr_date_max: :date,
    attr_geolocation: :string,
    attr_geolocation_radius: :integer,
    project_id: :string,
    # Map of project attribute ID => filter (see `project_attribute_filters/1`)
    project_attributes: :map,
    no_media_versions: :boolean,
    # User id
    only_subscribed_id: :string,
    # User id
    only_assigned_id: :string,
    # User id
    has_been_edited_by_id: :string,
    only_has_unread_notifications: :boolean,
    display: :string,
    deleted: :boolean,
    page: :integer
  }

  def changeset(params \\ %{}) do
    data = %{}

    {data, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.validate_change(:attr_geolocation, fn _, value ->
      case parse_location(value) do
        :error ->
          [
            attr_geolocation:
              "Invalid location. Please enter a valid latitude and longitude, separated by a comma."
          ]

        _ ->
          []
      end
    end)
    |> Ecto.Changeset.validate_length(:query, max: 256)
    |> Ecto.Changeset.validate_inclusion(:sort, [
      "uploaded_desc",
      "uploaded_asc",
      "modified_desc",
      "modified_asc",
      "description_desc",
      "description_asc",
      "date_desc",
      "date_asc"
    ])
  end

  @doc """
  Returns the project (custom) attribute filters in the given search changeset, as a map
  of attribute ID => %{values: [string], text: string | nil, date_min: string | nil, date_max: string | nil}.
  Attributes without any active filter are omitted.
  """
  def project_attribute_filters(%Ecto.Changeset{} = changeset) do
    case Ecto.Changeset.get_field(changeset, :project_attributes) do
      filters when is_map(filters) ->
        filters
        |> Enum.flat_map(fn {id, filter} ->
          with {:ok, id} <- UUID.cast(id),
               filter when is_map(filter) <- filter do
            normalized = %{
              values: normalize_filter_values(Map.get(filter, "values")),
              text: normalize_filter_text(Map.get(filter, "text")),
              date_min: normalize_filter_date(Map.get(filter, "date_min")),
              date_max: normalize_filter_date(Map.get(filter, "date_max"))
            }

            if normalized == %{values: [], text: nil, date_min: nil, date_max: nil},
              do: [],
              else: [{id, normalized}]
          else
            _ -> []
          end
        end)
        |> Map.new()

      _ ->
        %{}
    end
  end

  @doc """
  Returns the filter for the given project attribute ID in the search changeset, or nil if it is not being filtered.
  """
  def project_attribute_filter(%Ecto.Changeset{} = changeset, attribute_id) do
    Map.get(project_attribute_filters(changeset), attribute_id)
  end

  defp normalize_filter_values(values) when is_list(values) do
    values
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
    |> Enum.uniq()
    |> Enum.take(512)
  end

  defp normalize_filter_values(_), do: []

  defp normalize_filter_text(text) when is_binary(text) do
    case text |> String.trim() |> String.slice(0, 256) do
      "" -> nil
      text -> text
    end
  end

  defp normalize_filter_text(_), do: nil

  defp normalize_filter_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, date} -> Date.to_iso8601(date)
      _ -> nil
    end
  end

  defp normalize_filter_date(_), do: nil

  defp parse_location(location_string) do
    coords =
      (location_string || "")
      |> String.trim()
      |> String.split(",")

    case coords do
      [""] ->
        nil

      [lat_string, lon_string] ->
        with {lat, ""} <- Float.parse(lat_string |> String.trim()),
             {lon, ""} <- Float.parse(lon_string |> String.trim()) do
          %Geo.Point{
            coordinates: {lon, lat},
            srid: 4326
          }
        else
          _ -> :error
        end

      _ ->
        :error
    end
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
      [] -> queryable
      query -> where(queryable, [m], m.attr_status in ^query)
    end
  end

  defp apply_query_component(queryable, changeset, :attr_date_min) do
    case Map.get(changeset.changes, :attr_date_min) do
      nil -> queryable
      query -> where(queryable, [m], m.attr_date >= ^query)
    end
  end

  defp apply_query_component(queryable, changeset, :attr_date_max) do
    case Map.get(changeset.changes, :attr_date_max) do
      nil -> queryable
      query -> where(queryable, [m], m.attr_date <= ^query)
    end
  end

  defp apply_query_component(queryable, changeset, :attr_tags) do
    case Map.get(changeset.changes, :attr_tags) do
      nil ->
        queryable

      [] ->
        queryable

      # Or, there must be some intersection between the two arrays
      values ->
        where(
          queryable,
          [m],
          fragment("? && ?", m.attr_tags, ^values) or
            ("[Unset]" in ^values and (is_nil(m.attr_tags) or m.attr_tags == ^[]))
        )
    end
  end

  defp apply_query_component(queryable, changeset, :attr_sensitive) do
    case Map.get(changeset.changes, :attr_sensitive) do
      nil ->
        queryable

      [] ->
        queryable

      # Or, there must be some intersection between the two arrays
      values ->
        where(
          queryable,
          [m],
          fragment("? && ?", m.attr_sensitive, ^values) or
            ("[Unset]" in ^values and (is_nil(m.attr_sensitive) or m.attr_sensitive == ^[]))
        )
    end
  end

  defp apply_query_component(queryable, changeset, :attr_geolocation) do
    case parse_location(Map.get(changeset.changes, :attr_geolocation)) do
      # Or, there must be some intersection between the two arrays
      %Geo.Point{coordinates: {lon, lat}} ->
        where(
          queryable,
          [m],
          fragment(
            "ST_DWithin(?, St_SetSRID(ST_MakePoint(?, ?), 4326), ?)",
            m.attr_geolocation,
            ^lon,
            ^lat,
            ^(Map.get(changeset.changes, :attr_geolocation_radius, 10) * (0.01 / 1.11))
          )
        )

      _ ->
        queryable
    end
  end

  defp apply_query_component(queryable, changeset, :project_id) do
    case Map.get(changeset.changes, :project_id) do
      nil -> queryable
      "unset" -> where(queryable, [m], is_nil(m.project_id))
      value -> where(queryable, [m], m.project_id == ^value)
    end
  end

  defp apply_query_component(queryable, changeset, :project_attributes) do
    changeset
    |> project_attribute_filters()
    |> Enum.reduce(queryable, fn {id, filter}, queryable ->
      queryable
      |> apply_project_attribute_values_filter(id, filter.values)
      |> apply_project_attribute_text_filter(id, filter.text)
      |> apply_project_attribute_date_filter(id, filter.date_min, filter.date_max)
    end)
  end

  defp apply_query_component(queryable, changeset, :no_media_versions) do
    case Map.get(changeset.changes, :no_media_versions, nil) do
      nil ->
        queryable

      false ->
        where(
          queryable,
          [u],
          fragment(
            "EXISTS (SELECT * FROM media_versions other WHERE other.media_id = ? AND other.visibility = 'visible')",
            u.id
          )
        )

      true ->
        where(
          queryable,
          [u],
          fragment(
            "NOT EXISTS (SELECT * FROM media_versions other WHERE other.media_id = ? AND other.status = 'complete' AND other.visibility = 'visible')",
            u.id
          )
        )
    end
  end

  defp apply_query_component(queryable, changeset, :only_subscribed_id) do
    case UUID.cast(Map.get(changeset.changes, :only_subscribed_id, "")) do
      :error ->
        queryable

      {:ok, value} ->
        from q in queryable,
          join: s in assoc(q, :subscriptions),
          where: s.user_id == ^value
    end
  end

  defp apply_query_component(queryable, changeset, :only_assigned_id) do
    case UUID.cast(Map.get(changeset.changes, :only_assigned_id, "")) do
      :error ->
        queryable

      {:ok, value} ->
        from q in queryable,
          join: a in assoc(q, :attr_assignments),
          where: a.user_id == ^value
    end
  end

  defp apply_query_component(queryable, changeset, :has_been_edited_by_id) do
    case UUID.cast(Map.get(changeset.changes, :has_been_edited_by_id, "")) do
      :error ->
        queryable

      {:ok, value} ->
        from q in queryable,
          join: u in assoc(q, :updates),
          where: u.type != :comment and u.user_id == ^value
    end
  end

  defp apply_query_component(queryable, changeset, :only_has_unread_notifications, current_user) do
    case Map.get(changeset.changes, :only_has_unread_notifications, false) and
           not is_nil(current_user) do
      false ->
        queryable

      true ->
        from q in queryable,
          join: n in assoc(q, :notifications),
          where: n.user_id == ^current_user.id and n.read == false
    end
  end

  # Project attribute values are stored in the `project_attributes` JSONB array as
  # objects of the form {"id": attribute_id, "project_id": ..., "value": ...}.
  #
  # Text, date and unset filters cannot use the GIN index on `project_attributes`, so
  # they are evaluated for every incident in the project. They use JSON path queries
  # (passed as parameters) to reach the one attribute directly; unpacking the whole
  # array with jsonb_array_elements was 4-5x slower on large projects.

  # The value of the attribute $id
  @project_attribute_value_path ~s|$[*] ? (@.id == $id).value|

  # JSON path filters use the `@?` operator, rather than jsonb_path_exists(), so Postgres
  # can estimate how many incidents match from the column statistics; with a fixed guess
  # it can pick very slow plans for rare matches. The operator does not take variables,
  # so the (validated) ID and dates are embedded as JSON string literals.

  # Whether the attribute has a non-empty value
  defp project_attribute_set_path(id) do
    ~s|$[*] ? (@.id == #{Jason.encode!(id)} && @.value.type() != "null" && !(@.value.type() == "string" && @.value == "") && !(@.value.type() == "array" && @.value.size() == 0))|
  end

  # Whether the attribute is a date (an ISO 8601 string, so it compares lexicographically)
  # within the given bounds
  defp project_attribute_date_path(id, min, max) do
    bounds =
      [{">=", min}, {"<=", max}]
      |> Enum.reject(fn {_, date} -> is_nil(date) end)
      |> Enum.map(fn {op, date} -> " && @.value #{op} #{Jason.encode!(date)}" end)

    ~s|$[*] ? (@.id == #{Jason.encode!(id)} && @.value.type() == "string" && @.value != ""#{bounds})|
  end

  defp apply_project_attribute_values_filter(queryable, _id, []), do: queryable

  defp apply_project_attribute_values_filter(queryable, id, values) do
    # Like tags, the incident must match at least one of the given values
    conditions =
      Enum.reduce(values, dynamic(false), fn
        "[Unset]", acc ->
          path = project_attribute_set_path(id)

          dynamic(
            [m],
            ^acc or
              fragment(
                "(? IS NULL OR NOT (? @\\? ?::text::jsonpath))",
                m.project_attributes,
                m.project_attributes,
                ^path
              )
          )

        value, acc ->
          # Select values are stored as strings, and multi-select values as arrays of strings
          single = Jason.encode!([%{id: id, value: value}])
          multi = Jason.encode!([%{id: id, value: [value]}])

          dynamic(
            [m],
            ^acc or fragment("? @> ?::text::jsonb", m.project_attributes, ^single) or
              fragment("? @> ?::text::jsonb", m.project_attributes, ^multi)
          )
      end)

    where(queryable, ^conditions)
  end

  defp apply_project_attribute_text_filter(queryable, _id, nil), do: queryable

  defp apply_project_attribute_text_filter(queryable, id, text) do
    pattern = "%" <> String.replace(text, ~r/([\\%_])/, "\\\\\\1") <> "%"
    vars = Jason.encode!(%{id: id})

    where(
      queryable,
      [m],
      fragment(
        "jsonb_path_query_first(?, ?::text::jsonpath, ?::text::jsonb) #>> '{}' ILIKE ?",
        m.project_attributes,
        ^@project_attribute_value_path,
        ^vars,
        ^pattern
      )
    )
  end

  defp apply_project_attribute_date_filter(queryable, _id, nil, nil), do: queryable

  defp apply_project_attribute_date_filter(queryable, id, min, max) do
    path = project_attribute_date_path(id, min, max)

    where(queryable, [m], fragment("? @\\? ?::text::jsonpath", m.project_attributes, ^path))
  end

  defp apply_sort(queryable, changeset) do
    # Returns a {queryable, pagination_opts} tuple.
    uploaded_desc = {queryable |> Ecto.Query.order_by([i], desc: i.inserted_at), []}

    case Map.get(changeset.changes, :sort) do
      nil ->
        uploaded_desc

      query ->
        case query do
          "uploaded_desc" ->
            uploaded_desc

          "uploaded_asc" ->
            {queryable |> Ecto.Query.prepend_order_by([i], asc: i.inserted_at), []}

          "modified_desc" ->
            {queryable |> Ecto.Query.prepend_order_by([i], desc: i.updated_at), []}

          "modified_asc" ->
            {queryable |> Ecto.Query.prepend_order_by([i], asc: i.updated_at), []}

          "description_desc" ->
            {queryable |> Ecto.Query.prepend_order_by([i], desc: i.attr_description), []}

          "description_asc" ->
            {queryable |> Ecto.Query.prepend_order_by([i], asc: i.attr_description), []}

          "date_desc" ->
            {queryable |> Ecto.Query.prepend_order_by([i], desc: i.attr_date), []}

          "date_asc" ->
            {queryable |> Ecto.Query.prepend_order_by([i], asc: i.attr_date), []}
        end
    end
  end

  defp apply_deleted({queryable, options}, changeset) do
    # Returns a {queryable, pagination_opts} tuple.
    if Map.get(changeset.changes, :deleted, false) do
      {queryable |> Ecto.Query.where([u], u.deleted),
       Keyword.merge(options, include_deleted: true)}
    else
      {queryable |> Ecto.Query.where([u], not u.deleted),
       Keyword.merge(options, include_deleted: false)}
    end
  end

  @doc """
  Builds a composeable query given the search changeset. Returns a {queryable, pagination_opts} tuple.
  """
  def search_query(queryable \\ Media, %Ecto.Changeset{} = cs, current_user \\ nil) do
    queryable
    |> apply_query_component(cs, :query)
    |> apply_query_component(cs, :attr_status)
    |> apply_query_component(cs, :attr_tags)
    |> apply_query_component(cs, :attr_sensitive)
    |> apply_query_component(cs, :attr_date_min)
    |> apply_query_component(cs, :attr_date_max)
    |> apply_query_component(cs, :attr_geolocation)
    |> apply_query_component(cs, :no_media_versions)
    |> apply_query_component(cs, :project_id)
    |> apply_query_component(cs, :project_attributes)
    |> apply_query_component(cs, :only_subscribed_id)
    |> apply_query_component(cs, :only_assigned_id)
    |> apply_query_component(cs, :has_been_edited_by_id)
    |> apply_query_component(cs, :only_has_unread_notifications, current_user)
    |> apply_sort(cs)
    |> apply_deleted(cs)
  end

  @doc """
  Filters the query results so that they are viewable to the given user
  """
  def filter_viewable(queryable \\ Media, %Platform.Accounts.User{} = user) do
    queryable |> Platform.Material.maybe_filter_accessible_to_user(for_user: user)
  end
end
