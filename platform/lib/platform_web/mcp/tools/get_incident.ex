defmodule PlatformWeb.MCP.Tools.GetIncident do
  @behaviour PlatformWeb.MCP.Tool

  alias Platform.Material.Media
  alias PlatformWeb.MCP.Tools.Helpers

  @impl true
  def name, do: "get_incident"

  @impl true
  def description do
    "Get the full detail of one incident by its slug (e.g. \"CIV-1234\" or the bare slug), " <>
      "including all attribute values, project-defined attribute values, and its source " <>
      "material with artifact download links. Incidents may describe graphic or sensitive " <>
      "events; check the `sensitive` field before surfacing content to people."
  end

  @impl true
  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "slug" => %{
          "type" => "string",
          "description" => "The incident's slug, with or without the project code prefix."
        }
      },
      "required" => ["slug"],
      "additionalProperties" => false
    }
  end

  @impl true
  def required_permission, do: :read

  @impl true
  def read_only?, do: true

  @impl true
  def call(token, args) do
    with {:ok, slug} <- Helpers.require_string(args, "slug"),
         {:ok, media} <- Helpers.get_scoped_media(token, slug) do
      {:ok,
       %{
         incident: media,
         slug: Media.slug_to_display(media),
         url: PlatformWeb.Endpoint.url() <> "/incidents/" <> media.slug
       }}
    end
  end
end
