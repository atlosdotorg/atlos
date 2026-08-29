defmodule PlatformWeb.MCP.Tools.SearchIncidents do
  @behaviour PlatformWeb.MCP.Tool

  import Ecto.Query

  alias Platform.Material
  alias PlatformWeb.APISerialization
  alias PlatformWeb.MCP.Cursor
  alias PlatformWeb.MCP.Tools.Helpers

  @page_size 25

  @impl true
  def name, do: "search_incidents"

  @impl true
  def description do
    "Search the incidents in this project. All filters are optional; with no filters, " <>
      "returns the most recently modified incidents first. Results are paginated: pass the " <>
      "`cursor` from a previous result to fetch the next page. Returns compact incident " <>
      "summaries; use `get_incident` for full detail on a specific incident."
  end

  @impl true
  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
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
  def call(token, args) do
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

    base_query = from(m in Material.Media, where: m.project_id == ^token.project_id)
    changeset = Material.MediaSearch.changeset(search_params)

    cond do
      not changeset.valid? ->
        {:error, %{invalid_search_parameters: Helpers.changeset_errors(changeset)}}

      true ->
        {query, pagination_options} = Material.MediaSearch.search_query(base_query, changeset)

        with {:ok, after_cursor} <- Cursor.extract(args["cursor"], token.value) do
          results =
            Material.query_media_paginated(
              query,
              Keyword.merge(pagination_options,
                sort: "modified_desc",
                after: after_cursor,
                limit: @page_size
              )
            )

          {:ok,
           %{
             results: Enum.map(results.entries, &APISerialization.incident_summary/1),
             cursor: Cursor.sign(results.metadata.after, token.value)
           }}
        end
    end
  end

  defp put_present(map, _key, nil), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)
end
