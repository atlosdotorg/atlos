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
  alias Platform.Projects
  alias Platform.Projects.Project
  alias PlatformWeb.MCP.Context

  @doc """
  Fetch an incident by slug (raw or display form), scoped to the projects the
  context can reach and, for users, to incidents they can view. Returns the
  same error for a missing incident and one that is out of reach or hidden
  from the user, so slugs can't be probed.
  """
  def get_scoped_media(%Context{} = context, slug) when is_binary(slug) do
    media = Material.get_full_media_by_slug(slug)

    if is_nil(media) or
         not Context.has_permission_in_project?(context, media.project_id, :read) or
         not can_view_media?(context, media) do
      {:error, "incident not found"}
    else
      {:ok, media}
    end
  end

  def get_scoped_media(%Context{}, _slug), do: {:error, "slug must be a string"}

  @doc """
  Resolve the `project` argument (a project ID or code) to a project the
  context can reach. API tokens default to their own project. Users may omit
  it only if they can reach exactly one project.
  """
  def resolve_project(%Context{actor: %APIToken{}} = context, args) do
    project = Projects.get_project!(context.project_id)

    case Map.get(args, "project") do
      nil -> {:ok, project}
      value -> if matches_project?(project, value), do: {:ok, project}, else: project_not_found()
    end
  end

  def resolve_project(%Context{actor: %User{}} = context, args) do
    projects = Enum.map(Context.memberships(context), & &1.project)

    case {Map.get(args, "project"), projects} do
      {nil, [project]} ->
        {:ok, project}

      {nil, _} ->
        {:error, "project is required; call list_projects to see the projects you can use"}

      {value, _} ->
        case Enum.filter(projects, &matches_project?(&1, value)) do
          [project] -> {:ok, project}
          [] -> project_not_found()
          _ -> {:error, "more than one project has that code; pass the project's id instead"}
        end
    end
  end

  defp matches_project?(%Project{} = project, value) when is_binary(value),
    do: project.id == value or String.upcase(project.code || "") == String.upcase(value)

  defp matches_project?(_, _), do: false

  defp project_not_found,
    do: {:error, "project not found; call list_projects to see the projects you can use"}

  @doc """
  The `project` argument's JSON Schema, shared by the tools that take one.
  """
  def project_argument_schema(description) do
    %{
      "type" => "string",
      "description" =>
        description <>
          " Pass a project id or code from list_projects. May be omitted when only one project is available."
    }
  end

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
      Context.has_permission_in_project?(context, media.project_id, :comment) and
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
    do:
      Context.has_permission_in_project?(context, media.project_id, :edit) and
        Permissions.can_edit_media?(user, media)

  def can_edit?(%Context{actor: %User{} = user} = context, %Media{} = media, %Attribute{} = attr),
    do:
      Context.has_permission_in_project?(context, media.project_id, :edit) and
        Permissions.can_edit_media?(user, media, attr)

  @doc """
  Whether the actor can create incidents in the project.
  """
  def can_create_media?(%Context{actor: %APIToken{} = token}, %Project{}),
    do: Permissions.can_api_token_create_media?(token)

  def can_create_media?(%Context{actor: %User{} = user} = context, %Project{} = project) do
    Context.has_permission_in_project?(context, project.id, :edit) and
      Permissions.can_create_media?(user) and
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
