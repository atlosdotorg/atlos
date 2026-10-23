defmodule PlatformWeb.MCP.Context do
  @moduledoc """
  Who an MCP request acts as, and within which project.

  A request is authenticated either by a project API token, in which case it
  acts as that token, or by an OAuth access token, in which case it acts as
  the user who authorized the client. Either way it is scoped to exactly one
  project and carries a set of permissions (`:read`, `:comment`, `:edit`)
  used to decide which tools are listed. Tools still run the full permission
  checks for the actor on every call.
  """

  alias Platform.API.APIToken
  alias Platform.Accounts.User
  alias Platform.OAuth.Grant

  @enforce_keys [:actor, :project_id, :permissions, :cursor_salt]
  defstruct [:actor, :project_id, :permissions, :cursor_salt, :oauth_grant]

  @type t :: %__MODULE__{
          actor: APIToken.t() | User.t(),
          project_id: binary(),
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
      project_id: grant.project_id,
      permissions: Enum.map(scopes, &String.to_existing_atom/1),
      # Cursors are signed with the endpoint's secret; the salt only ties them
      # to this grant, so it need not be secret.
      cursor_salt: "mcp-oauth-grant:" <> grant.id,
      oauth_grant: grant
    }
  end

  def has_permission?(%__MODULE__{permissions: permissions}, permission),
    do: permission in permissions

  @doc """
  Metadata identifying the actor, for audit log entries.
  """
  def audit_metadata(%__MODULE__{actor: %APIToken{} = token}), do: %{api_token_id: token.id}

  def audit_metadata(%__MODULE__{actor: %User{} = user, oauth_grant: grant}),
    do: %{user_id: user.id, oauth_client_id: grant && grant.client_id}
end
