defmodule PlatformWeb.MCP.Tools.GetProject do
  @behaviour PlatformWeb.MCP.Tool

  alias Platform.Projects
  alias PlatformWeb.APISerialization

  @impl true
  def name, do: "get_project"

  @impl true
  def description do
    "Get the Atlos project this token is scoped to, including the full list of its " <>
      "attribute definitions. Each attribute definition has an `id` (pass this to " <>
      "`update_incident_attribute` and `create_incident`), a human-readable name, a type " <>
      "(select, multi_select, text, or date), and the available options for select-type " <>
      "attributes. Call this before creating or updating incidents so you know which " <>
      "attributes and values are valid."
  end

  @impl true
  def input_schema do
    %{
      "type" => "object",
      "properties" => %{},
      "additionalProperties" => false
    }
  end

  @impl true
  def required_permission, do: :read

  @impl true
  def read_only?, do: true

  @impl true
  def call(token, _args) do
    project = Projects.get_project!(token.project_id)
    {:ok, %{project: APISerialization.project_with_attributes(project)}}
  end
end
