defmodule PlatformWeb.APISerialization do
  @moduledoc """
  Shared serialization helpers for the JSON API and the MCP endpoint.
  """

  alias Platform.Material.Attribute
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
end
