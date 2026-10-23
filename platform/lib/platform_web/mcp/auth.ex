defmodule PlatformWeb.MCP.Auth do
  @moduledoc """
  Authentication for the MCP endpoint. Accepts either an OAuth access token
  (acting as a user) or a project-scoped, non-legacy API token, and assigns a
  `PlatformWeb.MCP.Context` as `:mcp_context`.

  Failed authentication returns 401 with a `WWW-Authenticate` header pointing
  at the protected resource metadata (RFC 9728), which is how MCP clients
  discover the OAuth authorization server.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Platform.API
  alias Platform.OAuth
  alias PlatformWeb.MCP.Context

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> provided] -> authenticate(conn, provided)
      _ -> unauthorized(conn)
    end
  end

  defp authenticate(conn, provided) do
    if OAuth.access_token?(provided) do
      case OAuth.authenticate_access_token(provided) do
        {:ok, grant, scopes} ->
          assign(conn, :mcp_context, Context.from_oauth_grant(grant, scopes))

        :error ->
          unauthorized(conn, "invalid_token")
      end
    else
      case API.get_api_token_by_value(provided) do
        %API.APIToken{is_active: true, is_legacy: false, project_id: project_id} = token
        when not is_nil(project_id) ->
          conn
          |> assign(:token, token)
          |> assign(:mcp_context, Context.from_api_token(token))

        _ ->
          unauthorized(conn, "invalid_token")
      end
    end
  end

  defp unauthorized(conn, error \\ nil) do
    challenge =
      ["Bearer resource_metadata=\"#{resource_metadata_url()}\""]
      |> then(fn parts -> if error, do: parts ++ ["error=\"#{error}\""], else: parts end)
      |> Enum.join(", ")

    conn
    |> put_resp_header("www-authenticate", challenge)
    |> put_status(:unauthorized)
    |> json(%{error: "invalid token or token not found"})
    |> halt()
  end

  def resource_url, do: PlatformWeb.Endpoint.url() <> "/mcp"

  def resource_metadata_url,
    do: PlatformWeb.Endpoint.url() <> "/.well-known/oauth-protected-resource/mcp"
end
