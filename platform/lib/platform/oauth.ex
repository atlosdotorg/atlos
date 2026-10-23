defmodule Platform.OAuth do
  @moduledoc """
  OAuth 2.1 authorization server for the MCP endpoint.

  Users authorize an MCP client (registered through dynamic client
  registration) to act as them within a single project. The resulting access
  token carries a set of scopes — `read`, `comment`, and `edit`, mirroring API
  token permissions — and on every request is further limited by the user's
  current role in the project, so a token never grants more than the user
  could do in the web app.

  All clients are public clients: there are no client secrets, and the
  authorization code flow requires PKCE (S256). Codes and tokens are stored
  only as SHA-256 hashes.
  """

  import Ecto.Query, warn: false

  alias Platform.Accounts
  alias Platform.Accounts.User
  alias Platform.OAuth.AuthorizationCode
  alias Platform.OAuth.Client
  alias Platform.OAuth.Grant
  alias Platform.Projects
  alias Platform.Projects.ProjectMembership
  alias Platform.Repo

  @scopes ["read", "comment", "edit"]

  @code_ttl_seconds 10 * 60
  @access_token_ttl_seconds 60 * 60
  @refresh_token_ttl_seconds 30 * 24 * 60 * 60

  @access_token_prefix "atlos_oat_"
  @refresh_token_prefix "atlos_ort_"

  def scopes, do: @scopes
  def access_token_ttl_seconds, do: @access_token_ttl_seconds

  def random_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp hash_token(token), do: :crypto.hash(:sha256, token)

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  @doc """
  Whether a bearer token looks like an OAuth access token (as opposed to a
  project API token).
  """
  def access_token?(token),
    do: is_binary(token) and String.starts_with?(token, @access_token_prefix)

  ## Scopes and roles

  @doc """
  The scopes a member with the given role may grant. Data-only viewers can't
  connect MCP clients: they can't see the activity feed or project members,
  and the MCP tools don't model those restrictions.
  """
  def scopes_for_role(role) when role in [:owner, :manager, :editor], do: @scopes
  def scopes_for_role(:viewer), do: ["read", "comment"]
  def scopes_for_role(_), do: []

  @doc """
  Parse a space-delimited OAuth scope string. A missing or blank scope means
  every scope. Returns `{:ok, scopes}` (always including `read`) or `:error`
  if any scope is unknown.
  """
  def parse_scope(nil), do: {:ok, @scopes}

  def parse_scope(scope) when is_binary(scope) do
    requested = String.split(scope, " ", trim: true)

    cond do
      requested == [] -> {:ok, @scopes}
      Enum.all?(requested, &(&1 in @scopes)) -> {:ok, normalize_scopes(["read" | requested])}
      true -> :error
    end
  end

  def parse_scope(_), do: :error

  defp normalize_scopes(scopes), do: Enum.filter(@scopes, &(&1 in scopes))

  @doc """
  The project memberships through which the user may authorize a client:
  every membership except data-only viewer, in active or archived projects.
  Projects where the user can grant the most access come first, so the
  consent screen's default choice matches its default access level.
  """
  def grantable_memberships(%User{} = user) do
    Projects.get_users_project_memberships(user)
    |> Enum.filter(&(scopes_for_role(&1.role) != []))
    |> Enum.sort_by(&{-length(scopes_for_role(&1.role)), String.downcase(&1.project.name)})
  end

  @doc """
  Whether the user may currently use OAuth access at all (mirrors the checks
  in `PlatformWeb.UserAuth.require_authenticated_user/2`).
  """
  def user_can_use_oauth?(%User{} = user) do
    not Accounts.is_suspended(user) and
      (Accounts.is_admin(user) or Platform.Security.get_security_mode_state() != :no_access)
  end

  ## Clients

  def register_client(attrs) do
    %Client{}
    |> Client.registration_changeset(attrs)
    |> Repo.insert()
  end

  def get_client_by_client_id(client_id) when is_binary(client_id) do
    Repo.get_by(Client, client_id: client_id)
  end

  def get_client_by_client_id(_), do: nil

  ## Authorization codes

  @doc """
  Issue an authorization code after the user approves a client. The scopes
  must be ones the user's role in the project allows. Returns the plaintext
  code, which is shown to the client exactly once.
  """
  def create_authorization_code(
        %Client{} = client,
        %User{} = user,
        project_id,
        scopes,
        redirect_uri,
        code_challenge
      ) do
    membership = Projects.get_project_membership_by_user_and_project_id(user, project_id)

    cond do
      is_nil(membership) or membership.user_id != user.id ->
        {:error, :invalid_project}

      not Enum.all?(scopes, &(&1 in scopes_for_role(membership.role))) or
          "read" not in scopes ->
        {:error, :invalid_scope}

      not Client.redirect_uri_allowed?(client, redirect_uri) ->
        {:error, :invalid_redirect_uri}

      true ->
        code = random_token()

        {:ok, _} =
          %AuthorizationCode{
            code_hash: hash_token(code),
            client_id: client.id,
            user_id: user.id,
            project_id: project_id,
            scopes: normalize_scopes(scopes),
            redirect_uri: redirect_uri,
            code_challenge: code_challenge,
            expires_at: DateTime.add(now(), @code_ttl_seconds, :second)
          }
          |> Repo.insert()

        {:ok, code}
    end
  end

  @doc """
  Exchange an authorization code for tokens (the `authorization_code` grant).
  Returns `{:ok, tokens}` or `{:error, oauth_error_code, description}`.

  A code can be used once. If it is presented again, every grant issued from
  it is revoked, as the code has likely leaked (OAuth 2.1 section 4.1.3).
  """
  def exchange_authorization_code(client_id, code, redirect_uri, code_verifier) do
    with %Client{} = client <- get_client_by_client_id(client_id) || {:error, :invalid_client},
         true <- is_binary(code) || {:error, :invalid_grant},
         %AuthorizationCode{} = auth_code <-
           Repo.get_by(AuthorizationCode, code_hash: hash_token(code)) || {:error, :invalid_grant},
         true <- auth_code.client_id == client.id || {:error, :invalid_grant},
         :ok <- consume_code(auth_code),
         true <- DateTime.compare(auth_code.expires_at, now()) == :gt || {:error, :invalid_grant},
         true <- auth_code.redirect_uri == redirect_uri || {:error, :invalid_grant},
         true <- pkce_valid?(auth_code.code_challenge, code_verifier) || {:error, :invalid_grant} do
      issue_grant(auth_code)
    else
      {:error, :invalid_client} ->
        {:error, "invalid_client", "unknown client_id"}

      {:error, :code_reused} ->
        {:error, "invalid_grant", "authorization code has already been used"}

      {:error, :invalid_grant} ->
        {:error, "invalid_grant", "invalid, expired, or mismatched authorization code"}
    end
  end

  defp consume_code(%AuthorizationCode{} = auth_code) do
    {count, _} =
      from(c in AuthorizationCode, where: c.id == ^auth_code.id and is_nil(c.used_at))
      |> Repo.update_all(set: [used_at: now()])

    if count == 1 do
      :ok
    else
      from(g in Grant, where: g.authorization_code_id == ^auth_code.id and is_nil(g.revoked_at))
      |> Repo.update_all(set: [revoked_at: now()])

      {:error, :code_reused}
    end
  end

  defp pkce_valid?(challenge, verifier) when is_binary(challenge) and is_binary(verifier) do
    String.length(verifier) in 43..128 and
      Plug.Crypto.secure_compare(
        :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false),
        challenge
      )
  end

  defp pkce_valid?(_, _), do: false

  defp issue_grant(%AuthorizationCode{} = auth_code) do
    access_token = @access_token_prefix <> random_token()
    refresh_token = @refresh_token_prefix <> random_token()
    issued_at = now()

    {:ok, grant} =
      %Grant{
        access_token_hash: hash_token(access_token),
        refresh_token_hash: hash_token(refresh_token),
        client_id: auth_code.client_id,
        user_id: auth_code.user_id,
        project_id: auth_code.project_id,
        authorization_code_id: auth_code.id,
        scopes: auth_code.scopes,
        access_token_expires_at: DateTime.add(issued_at, @access_token_ttl_seconds, :second),
        refresh_token_expires_at: DateTime.add(issued_at, @refresh_token_ttl_seconds, :second)
      }
      |> Repo.insert()

    {:ok, token_response(grant, access_token, refresh_token)}
  end

  defp token_response(%Grant{} = grant, access_token, refresh_token) do
    %{
      access_token: access_token,
      token_type: "Bearer",
      expires_in: @access_token_ttl_seconds,
      refresh_token: refresh_token,
      scope: Enum.join(grant.scopes, " ")
    }
  end

  @doc """
  Exchange a refresh token for a new access token and refresh token (the
  `refresh_token` grant). Both tokens are rotated; the old ones stop working.
  A client may ask for a subset of the originally granted scopes.
  """
  def refresh(client_id, refresh_token, scope \\ nil) do
    access_token = @access_token_prefix <> random_token()
    new_refresh_token = @refresh_token_prefix <> random_token()
    issued_at = now()

    with %Client{} = client <- get_client_by_client_id(client_id) || {:error, :invalid_client},
         true <- is_binary(refresh_token) || {:error, :invalid_grant},
         %Grant{} = grant <-
           Repo.get_by(Grant, refresh_token_hash: hash_token(refresh_token)) ||
             {:error, :invalid_grant},
         true <- grant.client_id == client.id || {:error, :invalid_grant},
         true <- is_nil(grant.revoked_at) || {:error, :invalid_grant},
         true <-
           DateTime.compare(grant.refresh_token_expires_at, issued_at) == :gt ||
             {:error, :invalid_grant},
         {:ok, scopes} <- refreshed_scopes(grant, scope),
         {1, [grant]} <-
           from(g in Grant,
             where:
               g.id == ^grant.id and g.refresh_token_hash == ^hash_token(refresh_token) and
                 is_nil(g.revoked_at),
             select: g
           )
           |> Repo.update_all(
             set: [
               access_token_hash: hash_token(access_token),
               refresh_token_hash: hash_token(new_refresh_token),
               scopes: scopes,
               access_token_expires_at:
                 DateTime.add(issued_at, @access_token_ttl_seconds, :second),
               refresh_token_expires_at:
                 DateTime.add(issued_at, @refresh_token_ttl_seconds, :second),
               updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
             ]
           ) do
      {:ok, token_response(grant, access_token, new_refresh_token)}
    else
      {:error, :invalid_client} -> {:error, "invalid_client", "unknown client_id"}
      {:error, :invalid_scope} -> {:error, "invalid_scope", "scope exceeds the original grant"}
      _ -> {:error, "invalid_grant", "invalid, expired, or revoked refresh token"}
    end
  end

  defp refreshed_scopes(%Grant{scopes: granted}, nil), do: {:ok, granted}

  defp refreshed_scopes(%Grant{scopes: granted}, scope) do
    case parse_scope(scope) do
      {:ok, requested} ->
        if Enum.all?(requested, &(&1 in granted)),
          do: {:ok, requested},
          else: {:error, :invalid_scope}

      :error ->
        {:error, :invalid_scope}
    end
  end

  @doc """
  Revoke the grant that an access or refresh token belongs to (RFC 7009).
  Unknown tokens are ignored, as the RFC requires.
  """
  def revoke_token(token) when is_binary(token) do
    hash = hash_token(token)

    from(g in Grant,
      where:
        (g.access_token_hash == ^hash or g.refresh_token_hash == ^hash) and is_nil(g.revoked_at)
    )
    |> Repo.update_all(set: [revoked_at: now()])

    :ok
  end

  def revoke_token(_), do: :ok

  ## Using access tokens

  @doc """
  Look up the grant for an access token, if the token is valid: unexpired,
  unrevoked, and belonging to a user who can still use OAuth and is still a
  member of the project in a role that can grant access. Returns
  `{:ok, grant, scopes}`, where `scopes` are the granted scopes limited to
  what the user's current role allows, or `:error`.
  """
  def authenticate_access_token(token) when is_binary(token) do
    with %Grant{} = grant <-
           Repo.get_by(Grant, access_token_hash: hash_token(token))
           |> Repo.preload([:user, :client]),
         true <- is_nil(grant.revoked_at),
         true <- DateTime.compare(grant.access_token_expires_at, now()) == :gt,
         true <- user_can_use_oauth?(grant.user),
         %ProjectMembership{} = membership <-
           Projects.get_project_membership_by_user_and_project_id(grant.user, grant.project_id),
         scopes when scopes != [] <-
           Enum.filter(grant.scopes, &(&1 in scopes_for_role(membership.role))) do
      touch_grant(grant)
      {:ok, grant, scopes}
    else
      _ -> :error
    end
  end

  def authenticate_access_token(_), do: :error

  # Record that the grant was used, at most once a minute to avoid a write on
  # every request.
  defp touch_grant(%Grant{last_used_at: last_used_at} = grant) do
    if is_nil(last_used_at) or DateTime.diff(now(), last_used_at) >= 60 do
      from(g in Grant, where: g.id == ^grant.id)
      |> Repo.update_all(set: [last_used_at: now()])
    end
  end

  ## Managing grants

  @doc """
  The user's active (unrevoked, unexpired) grants, most recently created first.
  """
  def list_active_grants(%User{} = user) do
    from(g in Grant,
      where:
        g.user_id == ^user.id and is_nil(g.revoked_at) and
          g.refresh_token_expires_at > ^now(),
      order_by: [desc: g.inserted_at],
      preload: [:client, :project]
    )
    |> Repo.all()
  end

  @doc """
  Revoke one of the user's grants. Users can only revoke their own grants.
  """
  def revoke_user_grant(%User{} = user, grant_id) do
    case Ecto.UUID.cast(grant_id) do
      {:ok, id} ->
        {count, _} =
          from(g in Grant, where: g.id == ^id and g.user_id == ^user.id and is_nil(g.revoked_at))
          |> Repo.update_all(set: [revoked_at: now()])

        if count == 1, do: :ok, else: {:error, :not_found}

      :error ->
        {:error, :not_found}
    end
  end
end
