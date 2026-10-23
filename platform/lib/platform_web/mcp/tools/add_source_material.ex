defmodule PlatformWeb.MCP.Tools.AddSourceMaterial do
  @behaviour PlatformWeb.MCP.Tool

  alias Platform.Auditor
  alias Platform.Material
  alias PlatformWeb.MCP.Context
  alias PlatformWeb.MCP.Tools.Helpers

  @impl true
  def name, do: "add_source_material"

  @impl true
  def title, do: "Add source material"

  @impl true
  def description do
    "Add a piece of source material to an existing incident by URL. When `archive` is " <>
      "true, Atlos archives the URL's content (screenshots, media files) asynchronously — " <>
      "the returned source material will initially have status \"pending\". When false, an " <>
      "empty piece of source material is created that references the URL without archiving it."
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
        "url" => %{
          "type" => "string",
          "description" => "The URL of the source material (must begin with http:// or https://)."
        },
        "archive" => %{
          "type" => "boolean",
          "description" => "Whether Atlos should archive the URL's content. Defaults to false."
        }
      },
      "required" => ["slug", "url"],
      "additionalProperties" => false
    }
  end

  @impl true
  def required_permission, do: :edit

  @impl true
  def read_only?, do: false

  @impl true
  def call(context, args) do
    should_archive = args["archive"] == true

    with {:ok, slug} <- Helpers.require_string(args, "slug"),
         {:ok, url} <- Helpers.require_string(args, "url"),
         {:ok, media} <- Helpers.get_scoped_media(context, slug) do
      cond do
        not Helpers.can_edit?(context, media) ->
          {:error, "not authorized to edit this incident"}

        true ->
          case Material.create_media_version_audited(media, context.actor, %{
                 upload_type: if(should_archive, do: :direct, else: :user_provided),
                 status: :pending,
                 source_url: url,
                 media_id: media.id
               }) do
            {:ok, version} ->
              Material.archive_media_version(version)

              Auditor.log(
                :media_version_uploaded,
                Map.merge(
                  %{media_slug: media.slug, source_url: url, via: "mcp"},
                  Context.audit_metadata(context)
                )
              )

              {:ok, %{source_material: version}}

            {:error, changeset} ->
              {:error, Helpers.changeset_errors(changeset)}
          end
      end
    end
  end
end
