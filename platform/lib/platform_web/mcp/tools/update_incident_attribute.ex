defmodule PlatformWeb.MCP.Tools.UpdateIncidentAttribute do
  @behaviour PlatformWeb.MCP.Tool

  alias Platform.Material
  alias Platform.Material.Attribute
  alias Platform.Permissions
  alias Platform.Projects
  alias PlatformWeb.MCP.Tools.Helpers

  @impl true
  def name, do: "update_incident_attribute"

  @impl true
  def description do
    "Set the value of one attribute on an incident. `attribute` is an attribute id from " <>
      "`get_project`: a core attribute's name (e.g. \"status\", \"description\", \"tags\") " <>
      "or a project-defined attribute's UUID. For select attributes pass a string; for " <>
      "multi-select attributes pass an array of strings. A `message` explaining the change " <>
      "is required and is recorded on the incident's activity feed alongside the change. " <>
      "Restricted attributes cannot be updated through this tool."
  end

  @impl true
  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "slug" => %{
          "type" => "string",
          "description" => "The incident's slug, with or without the project code prefix."
        },
        "attribute" => %{
          "type" => "string",
          "description" =>
            "The attribute id: a core attribute name or a project-defined attribute's UUID."
        },
        "value" => %{
          "description" =>
            "The new value: a string for text/select/date attributes, or an array of strings for multi-select attributes."
        },
        "message" => %{
          "type" => "string",
          "description" => "Explanation of the change, recorded on the incident's activity feed."
        }
      },
      "required" => ["slug", "attribute", "value", "message"],
      "additionalProperties" => false
    }
  end

  @impl true
  def required_permission, do: :edit

  @impl true
  def read_only?, do: false

  @impl true
  def call(token, args) do
    with {:ok, slug} <- Helpers.require_string(args, "slug"),
         {:ok, attribute_id} <- Helpers.require_string(args, "attribute"),
         {:ok, message} <- Helpers.require_string(args, "message"),
         {:ok, media} <- Helpers.get_scoped_media(token, slug) do
      project = Projects.get_project!(token.project_id)
      attribute = Attribute.get_attribute(attribute_id, project: project)
      value = Map.get(args, "value")

      cond do
        is_nil(value) ->
          {:error, "value is required"}

        is_nil(attribute) ->
          {:error, "attribute not found; call get_project to list this project's attribute ids"}

        attribute.is_restricted == true ->
          {:error, "this attribute is restricted and cannot be updated through MCP"}

        not Permissions.can_api_token_update_attribute?(token, media, attribute) ->
          {:error, "api token not authorized to edit"}

        true ->
          result =
            Material.update_media_attributes_audited(
              media,
              [attribute],
              Material.generate_attribute_change_params(attribute, value, project, %{
                "explanation" => message
              }),
              api_token: token
            )

          case result do
            {:ok, updated} ->
              {:ok, %{success: true, slug: Material.Media.slug_to_display(media), id: updated.id}}

            {:error, changeset} ->
              {:error, Helpers.changeset_errors(changeset)}
          end
      end
    end
  end
end
