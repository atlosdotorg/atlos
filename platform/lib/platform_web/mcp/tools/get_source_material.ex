defmodule PlatformWeb.MCP.Tools.GetSourceMaterial do
  @behaviour PlatformWeb.MCP.Tool

  alias Platform.Material
  alias PlatformWeb.MCP.Tools.Helpers

  @impl true
  def name, do: "get_source_material"

  @impl true
  def description do
    "Get one piece of source material by its ID (a UUID), including its archival status, " <>
      "metadata, and artifacts. Each artifact includes a time-limited signed `access_url` " <>
      "for downloading the underlying file. Source material may be graphic or sensitive; " <>
      "link to files rather than describing their contents unless asked."
  end

  @impl true
  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{
          "type" => "string",
          "description" => "The source material's UUID (from an incident's source material list)."
        }
      },
      "required" => ["id"],
      "additionalProperties" => false
    }
  end

  @impl true
  def required_permission, do: :read

  @impl true
  def read_only?, do: true

  @impl true
  def call(token, args) do
    with {:ok, id} <- Helpers.require_string(args, "id") do
      media_version =
        case Ecto.UUID.cast(id) do
          {:ok, _} -> Material.get_media_version(id)
          :error -> nil
        end

      if is_nil(media_version) or media_version.media.project_id != token.project_id do
        {:error, "source material not found"}
      else
        {:ok, %{source_material: media_version}}
      end
    end
  end
end
