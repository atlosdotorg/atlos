defmodule PlatformWeb.MCP.Tools.CreateIncident do
  @behaviour PlatformWeb.MCP.Tool

  alias Platform.Auditor
  alias Platform.Material
  alias Platform.Material.Attribute
  alias Platform.Projects
  alias PlatformWeb.APISerialization
  alias PlatformWeb.MCP.Context
  alias PlatformWeb.MCP.Tools.Helpers

  @impl true
  def name, do: "create_incident"

  @impl true
  def description do
    "Create a new incident in this project. `description` and `sensitive` are required " <>
      "core attributes. Additional attributes — core or project-defined — can be set via " <>
      "the `attributes` map, keyed by the attribute ids returned by `get_project`. URLs " <>
      "passed in `urls` are attached as source material and archived. Returns the created " <>
      "incident, including its slug."
  end

  @impl true
  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "description" => %{
          "type" => "string",
          "description" => "A one-sentence description of the incident (8-240 characters)."
        },
        "sensitive" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" =>
            "Sensitivity flags, e.g. [\"Not Sensitive\"] or values like \"Graphic Violence\" or \"Personal Information Visible\". Call get_project for the valid options."
        },
        "attributes" => %{
          "type" => "object",
          "description" =>
            "Additional attribute values, keyed by attribute id from get_project (core name or project-defined UUID)."
        },
        "urls" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "description" =>
            "URLs to attach as source material and archive. Must begin with http:// or https://."
        },
        "geolocation" => %{
          "type" => "string",
          "description" => "The incident's location, as \"latitude,longitude\"."
        }
      },
      "required" => ["description", "sensitive"],
      "additionalProperties" => false
    }
  end

  @impl true
  def required_permission, do: :edit

  @impl true
  def read_only?, do: false

  @impl true
  def call(context, args) do
    project = Projects.get_project!(context.project_id)

    attribute_values =
      Map.get(args, "attributes", %{})
      |> Map.merge(
        %{"description" => args["description"], "sensitive" => args["sensitive"]}
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()
      )

    unknown_attributes =
      attribute_values
      |> Enum.filter(fn {key, _} -> is_nil(Attribute.get_attribute(key, project: project)) end)
      |> Enum.map(fn {key, _} -> key end)

    forbidden_restricted_attributes =
      attribute_values
      |> Enum.map(fn {key, _} -> {key, Attribute.get_attribute(key, project: project)} end)
      |> Enum.filter(fn {_, attribute} ->
        match?(%Attribute{is_restricted: true}, attribute) and
          match?(%Platform.Accounts.User{}, context.actor) and
          not Helpers.can_set_restricted_attribute?(context, project, attribute)
      end)
      |> Enum.map(fn {key, _} -> key end)

    cond do
      not Helpers.can_create_media?(context, project) ->
        {:error, "not authorized to create incidents in this project"}

      not is_map(Map.get(args, "attributes", %{})) ->
        {:error, "attributes must be a map of attribute id to value"}

      unknown_attributes != [] ->
        {:error,
         "unknown attributes: #{inspect(unknown_attributes)}; call get_project to list this project's attribute ids"}

      forbidden_restricted_attributes != [] ->
        {:error,
         "only project owners and managers can set restricted attributes: #{inspect(forbidden_restricted_attributes)}"}

      true ->
        media_params =
          attribute_values
          |> Enum.reduce(%{}, fn {key, value}, acc ->
            Material.generate_attribute_change_params(
              Attribute.get_attribute(key, project: project),
              value,
              project,
              acc
            )
          end)
          |> Map.put("project_id", context.project_id)
          |> then(fn params ->
            case Map.get(args, "urls") do
              nil -> params
              urls when is_list(urls) -> Map.put(params, "urls", Jason.encode!(urls))
              _ -> params
            end
          end)
          |> then(fn params ->
            case Map.get(args, "geolocation") do
              nil -> params
              location -> Map.put(params, "location", location)
            end
          end)

        case Material.create_media_audited(context.actor, media_params) do
          {:ok, media} ->
            media = Platform.Repo.preload(media, [:project, :versions])

            Auditor.log(
              :media_created,
              Map.merge(%{media_slug: media.slug, via: "mcp"}, Context.audit_metadata(context))
            )

            {:ok, %{incident: APISerialization.incident_summary(media)}}

          {:error, changeset} ->
            {:error, Helpers.changeset_errors(changeset)}
        end
    end
  end
end
