defmodule PlatformWeb.MCP.Tools.SearchIncidents do
  @behaviour PlatformWeb.MCP.Tool

  import Ecto.Query

  alias Platform.Material
  alias PlatformWeb.APISerialization
  alias PlatformWeb.MCP.Context
  alias PlatformWeb.MCP.Cursor
  alias PlatformWeb.MCP.Tools.Helpers

  @page_size 25

  @impl true
  def name, do: "search_incidents"

  @impl true
  def title, do: "Search incidents"

  @impl true
  def description do
    "Search incidents, in one project or across every project you can access. All " <>
      "filters are optional; with no filters, " <>
      "returns the most recently modified incidents first. Results are paginated: pass the " <>
      "`cursor` from a previous result to fetch the next page. Returns compact incident " <>
      "summaries; use `get_incident` for full detail on a specific incident."
  end

  @impl true
  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "project" => %{
          "type" => "string",
          "description" =>
            "Optional project id or code from list_projects. Omit to search every project you can access."
        },
        "query" => %{
          "type" => "string",
          "description" =>
            "Full-text search over the incident's description, comments, and metadata."
        },
        "status" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" =>
            "Only include incidents with one of these statuses (e.g. \"To Do\", \"In Progress\", \"Ready for Review\", \"Completed\", \"Cancelled\")."
        },
        "tags" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" =>
            "Only include incidents with at least one of these tags. Use \"[Unset]\" for incidents with no tags."
        },
        "sensitive" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" => "Only include incidents with one of these sensitivity values."
        },
        "date_min" => %{
          "type" => "string",
          "description" => "Only include incidents on or after this date (YYYY-MM-DD)."
        },
        "date_max" => %{
          "type" => "string",
          "description" => "Only include incidents on or before this date (YYYY-MM-DD)."
        },
        "geolocation_center" => %{
          "type" => "string",
          "description" =>
            "Center of a geographic filter, as \"latitude,longitude\" (e.g. \"49.8397,24.0297\")."
        },
        "geolocation_radius_km" => %{
          "type" => "integer",
          "description" =>
            "Radius in whole kilometers around geolocation_center. Defaults to 10 when a center is given."
        },
        "no_source_material" => %{
          "type" => "boolean",
          "description" => "Only include incidents that have no source material."
        },
        "sort" => %{
          "type" => "string",
          "enum" => [
            "uploaded_desc",
            "uploaded_asc",
            "modified_desc",
            "modified_asc",
            "date_desc",
            "date_asc"
          ],
          "description" => "Sort order. Defaults to modified_desc."
        },
        "cursor" => %{
          "type" => "string",
          "description" => "Opaque pagination cursor from a previous result."
        }
      },
      "additionalProperties" => false
    }
  end

  @impl true
  def required_permission, do: :read

  @impl true
  def read_only?, do: true

  @impl true
  def call(context, args) do
    search_params =
      %{}
      |> put_present("query", args["query"])
      |> put_present("attr_status", args["status"])
      |> put_present("attr_tags", args["tags"])
      |> put_present("attr_sensitive", args["sensitive"])
      |> put_present("attr_date_min", args["date_min"])
      |> put_present("attr_date_max", args["date_max"])
      |> put_present("attr_geolocation", args["geolocation_center"])
      |> put_present("attr_geolocation_radius", args["geolocation_radius_km"])
      |> put_present("no_media_versions", args["no_source_material"])
      |> put_present("sort", args["sort"])

    changeset = Material.MediaSearch.changeset(search_params)

    project_ids_result =
      case Map.get(args, "project") do
        nil ->
          {:ok, Context.project_ids(context)}

        _ ->
          with {:ok, project} <- Helpers.resolve_project(context, args), do: {:ok, [project.id]}
      end

    cond do
      match?({:error, _}, project_ids_result) ->
        project_ids_result

      not changeset.valid? ->
        {:error, %{invalid_search_parameters: Helpers.changeset_errors(changeset)}}

      true ->
        {:ok, project_ids} = project_ids_result
        base_query = from(m in Material.Media, where: m.project_id in ^project_ids)
        {query, pagination_options} = Material.MediaSearch.search_query(base_query, changeset)

        with {:ok, after_cursor} <- Cursor.extract(args["cursor"], context.cursor_salt) do
          results =
            Material.query_media_paginated(
              query,
              Keyword.merge(pagination_options,
                sort: "modified_desc",
                after: after_cursor,
                limit: @page_size
              )
              |> Keyword.merge(visibility_options(context))
            )

          {:ok,
           %{
             results:
               Enum.map(results.entries, fn media ->
                 APISerialization.incident_summary(media)
                 |> Helpers.put_assignees(context, media)
               end),
             cursor: Cursor.sign(results.metadata.after, context.cursor_salt)
           }}
        end
    end
  end

  defp put_present(map, _key, nil), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  # Users only see the incidents they can view in the web app (hidden
  # incidents are visible only to owners and managers).
  defp visibility_options(%{actor: %Platform.Accounts.User{} = user}), do: [for_user: user]
  defp visibility_options(_context), do: []
end
