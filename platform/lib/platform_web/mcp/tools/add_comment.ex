defmodule PlatformWeb.MCP.Tools.AddComment do
  @behaviour PlatformWeb.MCP.Tool

  alias Platform.Permissions
  alias Platform.Updates
  alias PlatformWeb.MCP.Tools.Helpers

  @impl true
  def name, do: "add_comment"

  @impl true
  def description do
    "Post a comment on an incident's activity feed. The comment is attributed to this " <>
      "API token. Maximum length is 2,500 characters."
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
        "message" => %{
          "type" => "string",
          "description" => "The comment text (at most 2,500 characters)."
        }
      },
      "required" => ["slug", "message"],
      "additionalProperties" => false
    }
  end

  @impl true
  def required_permission, do: :comment

  @impl true
  def read_only?, do: false

  @impl true
  def call(token, args) do
    with {:ok, slug} <- Helpers.require_string(args, "slug"),
         {:ok, message} <- Helpers.require_string(args, "message"),
         {:ok, media} <- Helpers.get_scoped_media(token, slug) do
      cond do
        not Permissions.can_api_token_post_comment?(token, media) ->
          {:error, "api token not authorized to post comment"}

        true ->
          case Updates.post_comment_from_api_token(media, token, message) do
            {:ok, _} -> {:ok, %{success: true}}
            {:error, changeset} -> {:error, Helpers.changeset_errors(changeset)}
          end
      end
    end
  end
end
