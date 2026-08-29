defmodule PlatformWeb.MCP.Tools.Helpers do
  @moduledoc """
  Shared helpers for MCP tools.
  """

  alias Platform.API.APIToken
  alias Platform.Material

  @doc """
  Fetch an incident by slug (raw or display form), scoped to the token's
  project. Returns the same error for a missing incident and one outside the
  token's project, so slugs can't be probed across projects.
  """
  def get_scoped_media(%APIToken{} = token, slug) when is_binary(slug) do
    media = Material.get_full_media_by_slug(slug)

    if is_nil(media) or media.project_id != token.project_id do
      {:error, "incident not found"}
    else
      {:ok, media}
    end
  end

  def get_scoped_media(%APIToken{}, _slug), do: {:error, "slug must be a string"}

  @doc """
  Require a non-blank string argument.
  """
  def require_string(args, key) do
    case Map.get(args, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "#{key} is required and must be a non-empty string"}
    end
  end

  @doc """
  Render a changeset's errors as a map of field to message, suitable for
  returning to the model.
  """
  def changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
