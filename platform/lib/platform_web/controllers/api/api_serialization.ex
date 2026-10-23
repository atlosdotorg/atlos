defmodule PlatformWeb.APISerialization do
  @moduledoc """
  Shared serialization helpers for the JSON API and the MCP endpoint.
  """

  alias Platform.Material.Attribute
  alias Platform.Material.Media
  alias Platform.Projects.Project

  @doc """
  Serialize an attribute definition (core or project-defined) for API output.

  The `id` is the identifier accepted by the attribute-update endpoints and
  tools: a core attribute's name (e.g. "status") or a project-defined
  attribute's UUID.
  """
  def attribute_definition(%Attribute{} = attribute) do
    %{
      id: to_string(attribute.name),
      name: to_string(attribute.label),
      type: attribute.type,
      options: attribute.options || [],
      description: attribute.description,
      required: attribute.required == true,
      is_custom: attribute.schema_field == :project_attributes,
      is_restricted: attribute.is_restricted == true,
      decorator_for: if(attribute.is_decorator, do: to_string(attribute.parent), else: nil)
    }
  end

  @doc """
  Serialize a project with its full (active) attribute definitions.
  """
  def project_with_attributes(%Project{} = project) do
    %{
      id: project.id,
      name: project.name,
      code: project.code,
      description: project.description,
      color: project.color,
      active: project.active,
      attributes:
        Attribute.active_attributes(project: project)
        |> Enum.map(&attribute_definition/1)
    }
  end

  @doc """
  A compact serialization of an incident, suitable for search results. Expects
  the media's `project` and `versions` to be preloaded (as done by
  `Platform.Material.hydrate_media_query/2`).
  """
  def incident_summary(%Media{} = media) do
    project =
      case media.project do
        %Ecto.Association.NotLoaded{} -> nil
        other -> other
      end

    %{
      id: media.id,
      slug: Media.slug_to_display(media),
      url: PlatformWeb.Endpoint.url() <> "/incidents/" <> media.slug,
      description: media.attr_description,
      status: media.attr_status,
      date: media.attr_date,
      tags: media.attr_tags,
      sensitive: media.attr_sensitive,
      restrictions: media.attr_restrictions,
      geolocation: geolocation(media.attr_geolocation),
      custom_attributes: custom_attribute_values(media, project),
      source_material_count:
        case media.versions do
          %Ecto.Association.NotLoaded{} -> nil
          versions -> length(versions)
        end,
      deleted: media.deleted,
      inserted_at: media.inserted_at,
      updated_at: media.updated_at
    }
  end

  defp geolocation(%Geo.Point{coordinates: {lon, lat}}),
    do: %{latitude: lat, longitude: lon}

  defp geolocation(_), do: nil

  defp custom_attribute_values(%Media{}, nil), do: []

  defp custom_attribute_values(%Media{} = media, %Project{} = project) do
    project.attributes
    |> Enum.filter(& &1.enabled)
    |> Enum.map(fn definition ->
      %{
        id: definition.id,
        name: definition.name,
        value:
          media.project_attributes
          |> Enum.find(%{}, &(&1.id == definition.id))
          |> Map.get(:value)
      }
    end)
  end
end
