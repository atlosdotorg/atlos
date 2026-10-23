defmodule PlatformWeb.MCP.Tools.Helpers do
  @moduledoc """
  Shared helpers for MCP tools, including the permission checks that differ
  between the two kinds of actor (API tokens and OAuth users).
  """

  alias Platform.API.APIToken
  alias Platform.Accounts.User
  alias Platform.Material
  alias Platform.Material.Attribute
  alias Platform.Material.Media
  alias Platform.Permissions
  alias Platform.Projects.Project
  alias PlatformWeb.MCP.Context

  @doc """
  Fetch an incident by slug (raw or display form), scoped to the context's
  project and, for users, to incidents they can view. Returns the same error
  for a missing incident and one outside the project or hidden from the user,
  so slugs can't be probed.
  """
  def get_scoped_media(%Context{} = context, slug) when is_binary(slug) do
    media = Material.get_full_media_by_slug(slug)

    if is_nil(media) or media.project_id != context.project_id or
         not can_view_media?(context, media) do
      {:error, "incident not found"}
    else
      {:ok, media}
    end
  end

  def get_scoped_media(%Context{}, _slug), do: {:error, "slug must be a string"}

  defp can_view_media?(%Context{actor: %APIToken{}}, _media), do: true

  defp can_view_media?(%Context{actor: %User{} = user}, media),
    do: Permissions.can_view_media?(user, media)

  @doc """
  Whether the actor can post a comment on the incident.
  """
  def can_comment?(%Context{actor: %APIToken{} = token}, %Media{} = media),
    do: Permissions.can_api_token_post_comment?(token, media)

  def can_comment?(%Context{actor: %User{} = user} = context, %Media{} = media),
    do:
      Context.has_permission?(context, :comment) and
        Permissions.can_comment_on_media?(user, media)

  @doc """
  Whether the actor can edit the incident (add source material, or change the
  given attribute).
  """
  def can_edit?(context, media, attribute \\ nil)

  def can_edit?(%Context{actor: %APIToken{} = token}, %Media{} = media, nil),
    do: Permissions.can_api_token_edit_media?(token, media)

  def can_edit?(%Context{actor: %APIToken{} = token}, %Media{} = media, %Attribute{} = attribute),
    do: Permissions.can_api_token_update_attribute?(token, media, attribute)

  def can_edit?(%Context{actor: %User{} = user} = context, %Media{} = media, nil),
    do: Context.has_permission?(context, :edit) and Permissions.can_edit_media?(user, media)

  def can_edit?(%Context{actor: %User{} = user} = context, %Media{} = media, %Attribute{} = attr),
    do: Context.has_permission?(context, :edit) and Permissions.can_edit_media?(user, media, attr)

  @doc """
  Whether the actor can create incidents in the project.
  """
  def can_create_media?(%Context{actor: %APIToken{} = token}, %Project{}),
    do: Permissions.can_api_token_create_media?(token)

  def can_create_media?(%Context{actor: %User{} = user} = context, %Project{} = project) do
    Context.has_permission?(context, :edit) and Permissions.can_create_media?(user) and
      Permissions.can_add_media_to_project?(user, project)
  end

  @doc """
  Whether the actor can set a restricted attribute when creating an incident.
  API tokens never can.
  """
  def can_set_restricted_attribute?(%Context{actor: %APIToken{}}, _project, _attribute),
    do: false

  def can_set_restricted_attribute?(%Context{actor: %User{} = user}, project, attribute),
    do: Permissions.can_set_restricted_attribute_values_within_project?(user, project, attribute)

  @doc """
  Remove the source material the actor can't see (for users, material that
  has been removed is visible only to owners and managers).
  """
  def visible_versions(%Context{actor: %APIToken{}}, versions), do: versions

  def visible_versions(%Context{actor: %User{} = user}, versions) when is_list(versions),
    do: Enum.filter(versions, &Permissions.can_view_media_version?(user, &1))

  def visible_versions(%Context{}, versions), do: versions

  @doc """
  The keyword option identifying the actor, as expected by
  `Platform.Material.update_media_attributes_audited/4`.
  """
  def actor_opt(%Context{actor: %APIToken{} = token}), do: [api_token: token]
  def actor_opt(%Context{actor: %User{} = user}), do: [user: user]

  @doc """
  Require a non-blank string argument.
  """
  def require_string(args, key) do
    case Map.get(args, key) do
      value when is_binary(value) ->
        if String.trim(value) == "",
          do: {:error, "#{key} is required and must be a non-empty string"},
          else: {:ok, value}

      _ ->
        {:error, "#{key} is required and must be a non-empty string"}
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
