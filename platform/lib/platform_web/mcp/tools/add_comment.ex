defmodule PlatformWeb.MCP.Tools.AddComment do
  @behaviour PlatformWeb.MCP.Tool

  alias Platform.API.APIToken
  alias Platform.Accounts.User
  alias Platform.Updates
  alias PlatformWeb.MCP.Tools.Helpers

  @impl true
  def name, do: "add_comment"

  @impl true
  def description do
    "Post a comment on an incident's activity feed. The comment is attributed to the " <>
      "connected user, or to the API token. Maximum length is 2,500 characters."
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
  def call(context, args) do
    with {:ok, slug} <- Helpers.require_string(args, "slug"),
         {:ok, message} <- Helpers.require_string(args, "message"),
         {:ok, media} <- Helpers.get_scoped_media(context, slug) do
      cond do
        not Helpers.can_comment?(context, media) ->
          {:error, "not authorized to post a comment on this incident"}

        true ->
          case post_comment(context, media, message) do
            {:ok, _} -> {:ok, %{success: true}}
            {:error, changeset} -> {:error, Helpers.changeset_errors(changeset)}
          end
      end
    end
  end

  defp post_comment(%{actor: %APIToken{} = token}, media, message),
    do: Updates.post_comment_from_api_token(media, token, message)

  defp post_comment(%{actor: %User{} = user}, media, message) do
    Updates.change_from_comment(media, user, %{"explanation" => message})
    |> Updates.create_update_from_changeset()
  end
end
