defmodule PlatformWeb.OAuthController do
  @moduledoc """
  The machine-facing endpoints of the OAuth 2.1 authorization server used by
  MCP clients: discovery metadata (RFC 9728 and RFC 8414), dynamic client
  registration (RFC 7591), the token endpoint, and token revocation
  (RFC 7009). The user-facing consent screen is
  `PlatformWeb.OAuthAuthorizeController`.
  """

  use PlatformWeb, :controller

  alias Platform.OAuth
  alias PlatformWeb.MCP

  def protected_resource_metadata(conn, _params) do
    json(conn, %{
      resource: MCP.Auth.resource_url(),
      resource_name: "Atlos",
      authorization_servers: [issuer()],
      scopes_supported: OAuth.scopes(),
      bearer_methods_supported: ["header"]
    })
  end

  def authorization_server_metadata(conn, _params) do
    json(conn, %{
      issuer: issuer(),
      authorization_endpoint: issuer() <> "/oauth/authorize",
      token_endpoint: issuer() <> "/oauth/token",
      registration_endpoint: issuer() <> "/oauth/register",
      revocation_endpoint: issuer() <> "/oauth/revoke",
      scopes_supported: OAuth.scopes(),
      response_types_supported: ["code"],
      grant_types_supported: ["authorization_code", "refresh_token"],
      code_challenge_methods_supported: ["S256"],
      token_endpoint_auth_methods_supported: ["none"],
      revocation_endpoint_auth_methods_supported: ["none"],
      authorization_response_iss_parameter_supported: true
    })
  end

  def register(conn, params) do
    # Every client is registered as a public client using PKCE, whatever
    # authentication method it asked for (RFC 7591 section 3.2.1 lets the
    # server replace requested metadata).
    attrs = %{
      "client_name" => Map.get(params, "client_name") || "Unnamed MCP client",
      "redirect_uris" => Map.get(params, "redirect_uris")
    }

    case OAuth.register_client(attrs) do
      {:ok, client} ->
        conn
        |> put_status(:created)
        |> no_store()
        |> json(%{
          client_id: client.client_id,
          client_id_issued_at:
            DateTime.to_unix(DateTime.from_naive!(client.inserted_at, "Etc/UTC")),
          client_name: client.client_name,
          redirect_uris: client.redirect_uris,
          grant_types: ["authorization_code", "refresh_token"],
          response_types: ["code"],
          token_endpoint_auth_method: "none"
        })

      {:error, changeset} ->
        error =
          if Keyword.has_key?(changeset.errors, :redirect_uris),
            do: "invalid_redirect_uri",
            else: "invalid_client_metadata"

        conn
        |> put_status(:bad_request)
        |> json(%{
          error: error,
          error_description:
            PlatformWeb.MCP.Tools.Helpers.changeset_errors(changeset)
            |> Enum.map_join("; ", fn {field, messages} ->
              "#{field}: #{Enum.join(messages, ", ")}"
            end)
        })
    end
  end

  def token(conn, %{"grant_type" => "authorization_code"} = params) do
    OAuth.exchange_authorization_code(
      params["client_id"],
      params["code"],
      params["redirect_uri"],
      params["code_verifier"]
    )
    |> token_reply(conn)
  end

  def token(conn, %{"grant_type" => "refresh_token"} = params) do
    OAuth.refresh(params["client_id"], params["refresh_token"], params["scope"])
    |> token_reply(conn)
  end

  def token(conn, _params) do
    token_reply(
      {:error, "unsupported_grant_type",
       "grant_type must be authorization_code or refresh_token"},
      conn
    )
  end

  def revoke(conn, params) do
    :ok = OAuth.revoke_token(params["token"])
    conn |> no_store() |> json(%{})
  end

  defp token_reply({:ok, tokens}, conn), do: conn |> no_store() |> json(tokens)

  defp token_reply({:error, error, description}, conn) do
    conn
    |> put_status(if error == "invalid_client", do: :unauthorized, else: :bad_request)
    |> no_store()
    |> json(%{error: error, error_description: description})
  end

  defp no_store(conn) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("pragma", "no-cache")
  end

  def issuer, do: PlatformWeb.Endpoint.url()
end
