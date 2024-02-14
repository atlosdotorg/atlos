defmodule Platform.Material.MediaSearch do
  use Ecto.Schema
  import Ecto.Query
  alias Platform.Projects.ProjectAttribute
  alias Platform.Projects
  alias Ecto.UUID
  alias Platform.Material.Media
  alias Platform.Material.Attribute

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
    no_media_versions: :boolean,
    # User id
    only_subscribed_id: :string,
    # User id
    only_assigned_id: :string,
    # User id
    has_been_edited_by_id: :string,
    only_has_unread_notifications: :boolean,
    display: :string,
    deleted: :boolean
  }

  def changeset(params \\ %{}) do
    data = %{}

    new_types =
      case Map.get(params, "project_id") do
        nil ->
          @types

        pid ->
          case Projects.get_project(pid) do
            nil ->
              @types

            project ->
              Enum.reduce(project.attributes, @types, fn pattr, acc ->
                attr = ProjectAttribute.to_attribute(pattr)
                aid = get_attrid(attr)

                case attr.type do
                  :text ->
                    acc
                    |> Map.put(String.to_atom(aid), :string)
                    |> Map.put(String.to_atom("#{aid}-matchtype"), :string)

                  x when x == :multi_select or x == :select ->
                    acc |> Map.put(String.to_atom(aid), {:array, :string})

                  _ ->
                    acc |> Map.put(String.to_atom(aid), :string)
                end
              end)
          end
      end

    {data, new_types}
    |> Ecto.Changeset.cast(params, Map.keys(new_types))
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
      "description_asc"
    ])
  end

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

  defp apply_query_component(queryable, changeset, arbitrary_key) do
    # Filters for project attributes
    with rel_changes when not is_nil(rel_changes) <- Map.get(changeset.changes, arbitrary_key),
         project_id <- Map.get(changeset.changes, :project_id),
         project when not is_nil(project) <- Projects.get_project(project_id),
         attr when not is_nil(attr) <- Attribute.get_attribute(arbitrary_key, project: project),
         :project_attributes <- attr.schema_field do
      candidates = where(queryable, [m], m.project_id == ^project_id)

      case attr.type do
        :text ->
          case Map.get(changeset.changes, String.to_existing_atom("#{arbitrary_key}-matchtype")) do
            nil ->
              queryable

            match_type ->
              case {rel_changes, match_type} do
                {nil, _} ->
                  queryable

                {values, "contains"} ->
                  where(
                    candidates,
                    [m],
                    fragment(
                      "EXISTS (SELECT 1 FROM jsonb_array_elements(?) as elem WHERE elem->>'id' = ? AND elem->>'value' ILIKE ?)",
                      m.project_attributes,
                      ^attr.name,
                      ^"%#{values}%"
                    )
                  )

                {values, "equals"} ->
                  where(
                    candidates,
                    [m],
                    fragment(
                      "EXISTS (SELECT 1 FROM jsonb_array_elements(?) as elem WHERE elem->>'id' = ? AND elem->>'value' = ?)",
                      m.project_attributes,
                      ^attr.name,
                      ^values
                    )
                  )

                {values, "excludes"} ->
                  where(
                    candidates,
                    [m],
                    fragment(
                      "NOT EXISTS (SELECT 1 FROM jsonb_array_elements(?) as elem WHERE elem->>'id' = ? AND elem->>'value' ILIKE ?)",
                      m.project_attributes,
                      ^attr.name,
                      ^"%#{values}%"
                    )
                  )

                # TODO
                _ ->
                  queryable
              end
          end

        x when x == :multi_select or x == :select ->
          case rel_changes do
            nil ->
              queryable

            [] ->
              queryable

            values ->
              where(
                candidates,
                [m],
                fragment(
                  "EXISTS (SELECT 1 FROM jsonb_array_elements(?) AS elem WHERE elem->>'id' =? AND jsonb_typeof(elem->'value') = 'array' AND ARRAY(SELECT value FROM jsonb_array_elements_text(elem->'value')) && ?)",
                  m.project_attributes,
                  ^attr.name,
                  ^values
                )
              )
          end

        _ ->
          queryable
      end
    else
      _ ->
        queryable
    end
  end

  # defp apply_query_component(queryable, changeset, arbitrary_key) do
  #   Logger.debug("it goes here, #{inspect(arbitrary_key)}")
  #   queryable
  # end

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
    queryable =
      cs.changes
      |> Enum.reduce(queryable, fn {x, _}, acc ->
        apply_query_component(acc, cs, x)
      end)

    queryable
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

  def get_attrid(attr) do
    case attr.schema_field do
      :project_attributes -> attr.name
      sf -> Atom.to_string(sf)
    end
  end
end
