defmodule PlatformWeb.MCP.Context do
  @moduledoc """
  Who an MCP request acts as, and which projects it can reach.

  A request is authenticated either by a project API token, in which case it
  acts as that token within its one project, or by an OAuth access token, in
  which case it acts as the user who authorized the client, across every
  project they belong to (except as a data-only viewer).

  `permissions` (`:read`, `:comment`, `:edit`) decide which tools are listed:
  for a user, the granted scopes that at least one of their roles allows.
  Within a project, `permissions_in_project/2` further limits a user to what
  their role there allows, and tools still run the full permission checks for
  the actor on every call.
  """

  alias Platform.API.APIToken
  alias Platform.Accounts.User
  alias Platform.OAuth
  alias Platform.OAuth.Grant

  @enforce_keys [:actor, :permissions, :cursor_salt]
  defstruct [:actor, :project_id, :permissions, :cursor_salt, :oauth_grant]

  @type t :: %__MODULE__{
          actor: APIToken.t() | User.t(),
          project_id: binary() | nil,
          permissions: [:read | :comment | :edit],
          cursor_salt: binary(),
          oauth_grant: Grant.t() | nil
        }

  def from_api_token(%APIToken{} = token) do
    %__MODULE__{
      actor: token,
      project_id: token.project_id,
      permissions: token.permissions || [],
      cursor_salt: token.value
    }
  end

  def from_oauth_grant(%Grant{} = grant, scopes) do
    %__MODULE__{
      actor: grant.user,
      permissions: to_atoms(scopes),
      # Cursors are signed with the endpoint's secret; the salt only ties them
      # to this grant, so it need not be secret.
      cursor_salt: "mcp-oauth-grant:" <> grant.id,
      oauth_grant: grant
    }
  end

  def has_permission?(%__MODULE__{permissions: permissions}, permission),
    do: permission in permissions

  @doc """
  The memberships of the projects a user context can reach (each with its
  project preloaded). Not used for API tokens.
  """
  def memberships(%__MODULE__{actor: %User{} = user}), do: OAuth.accessible_memberships(user)

  @doc """
  The IDs of the projects this context can reach.
  """
  def project_ids(%__MODULE__{actor: %APIToken{}, project_id: project_id}), do: [project_id]

  def project_ids(%__MODULE__{actor: %User{}} = context),
    do: Enum.map(memberships(context), & &1.project_id)

  @doc """
  The permissions this context has within one project: none for a project
  it can't reach.
  """
  def permissions_in_project(%__MODULE__{actor: %APIToken{}} = context, project_id) do
    if project_id == context.project_id, do: context.permissions, else: []
  end

  def permissions_in_project(%__MODULE__{actor: %User{}} = context, project_id) do
    case Enum.find(memberships(context), &(&1.project_id == project_id)) do
      nil ->
        []

      membership ->
        context.oauth_grant.scopes |> OAuth.scopes_in_project(membership.role) |> to_atoms()
    end
  end

  def has_permission_in_project?(%__MODULE__{} = context, project_id, permission),
    do: permission in permissions_in_project(context, project_id)

  defp to_atoms(scopes), do: Enum.map(scopes, &String.to_existing_atom/1)

  @doc """
  Metadata identifying the actor, for audit log entries.
  """
  def audit_metadata(%__MODULE__{actor: %APIToken{} = token}), do: %{api_token_id: token.id}

  def audit_metadata(%__MODULE__{actor: %User{} = user, oauth_grant: grant}),
    do: %{user_id: user.id, oauth_client_id: grant && grant.client_id}
end
