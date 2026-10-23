defmodule PlatformWeb.OAuthAuthorizeController do
  @moduledoc """
  The OAuth authorization endpoint: a consent screen where a signed-in user
  chooses what level of access to give an MCP client across their projects.

  Request errors that can't be safely reported to the client (an unknown
  client, or a redirect URI the client didn't register) are shown to the user;
  everything else is reported by redirecting back to the client, per
  RFC 6749 section 4.1.2.1.
  """

  use PlatformWeb, :controller

  alias Platform.OAuth
  alias Platform.OAuth.Client
  alias PlatformWeb.MCP

  # Parameters carried from the authorization request through the consent form.
  @request_params ~w(client_id redirect_uri response_type code_challenge code_challenge_method state scope resource)

  def new(conn, params) do
    user = conn.assigns.current_user

    with {:ok, request} <- validate_request(conn, params) do
      render(conn, "new.html",
        title: "Connect #{request.client.client_name} to Atlos",
        request: request,
        request_params: Map.take(params, @request_params),
        memberships: OAuth.accessible_memberships(user),
        offered_scopes: Enum.filter(request.scopes, &(&1 in OAuth.max_scopes(user)))
      )
    end
  end

  def create(conn, %{"decision" => "approve"} = params) do
    user = conn.assigns.current_user

    with {:ok, request} <- validate_request(conn, params) do
      level_scopes =
        case params["access"] do
          "read" -> ["read"]
          "comment" -> ["read", "comment"]
          _ -> OAuth.scopes()
        end

      scopes =
        request.scopes
        |> Enum.filter(&(&1 in level_scopes))
        |> Enum.filter(&(&1 in OAuth.max_scopes(user)))

      case OAuth.create_authorization_code(
             request.client,
             user,
             scopes,
             request.redirect_uri,
             request.code_challenge
           ) do
        {:ok, code} ->
          Platform.Auditor.log(
            :oauth_client_authorized,
            %{
              client_id: request.client.client_id,
              client_name: request.client.client_name,
              scopes: scopes
            },
            conn
          )

          redirect_to_client(conn, request, %{"code" => code})

        {:error, _} ->
          conn
          |> put_flash(:error, "You need to be a member of a project to connect an application.")
          |> redirect(
            to: Routes.o_auth_authorize_path(conn, :new, Map.take(params, @request_params))
          )
      end
    end
  end

  def create(conn, params) do
    with {:ok, request} <- validate_request(conn, params) do
      redirect_to_client(conn, request, %{
        "error" => "access_denied",
        "error_description" => "the user denied the request"
      })
    end
  end

  defp validate_request(conn, params) do
    client = OAuth.get_client_by_client_id(params["client_id"])

    redirect_uri =
      case {params["redirect_uri"], client} do
        {nil, %Client{redirect_uris: [only]}} -> only
        {uri, _} -> uri
      end

    cond do
      is_nil(client) ->
        render_error(conn, "This application isn't registered with Atlos.")

      not Client.redirect_uri_allowed?(client, redirect_uri) ->
        render_error(conn, "This application's redirect address doesn't match its registration.")

      true ->
        request = %{client: client, redirect_uri: redirect_uri, state: params["state"]}

        with :ok <-
               check(
                 params["response_type"] == "code",
                 "unsupported_response_type",
                 "response_type must be code"
               ),
             :ok <-
               check(
                 is_binary(params["code_challenge"]) and params["code_challenge"] != "",
                 "invalid_request",
                 "code_challenge is required (PKCE)"
               ),
             :ok <-
               check(
                 params["code_challenge_method"] == "S256",
                 "invalid_request",
                 "code_challenge_method must be S256"
               ),
             :ok <-
               check(valid_resource?(params["resource"]), "invalid_target", "unknown resource"),
             {:ok, scopes} <- parse_scope(params["scope"]) do
          {:ok, Map.merge(request, %{scopes: scopes, code_challenge: params["code_challenge"]})}
        else
          {:error, error, description} ->
            redirect_to_client(conn, request, %{
              "error" => error,
              "error_description" => description
            })
        end
    end
  end

  defp check(true, _error, _description), do: :ok
  defp check(_, error, description), do: {:error, error, description}

  defp parse_scope(scope) do
    case OAuth.parse_scope(scope) do
      {:ok, scopes} ->
        {:ok, scopes}

      :error ->
        {:error, "invalid_scope", "supported scopes are: #{Enum.join(OAuth.scopes(), " ")}"}
    end
  end

  # The resource indicator (RFC 8707) is optional; when present it must name
  # the MCP endpoint, since that's the only resource these tokens are for.
  defp valid_resource?(nil), do: true

  defp valid_resource?(resource),
    do: String.trim_trailing(resource, "/") == MCP.Auth.resource_url()

  defp redirect_to_client(conn, request, response_params) do
    uri = URI.parse(request.redirect_uri)

    query =
      URI.decode_query(uri.query || "")
      |> Map.merge(response_params)
      |> Map.put("iss", PlatformWeb.OAuthController.issuer())
      |> then(fn q -> if request.state, do: Map.put(q, "state", request.state), else: q end)

    conn
    |> redirect(external: URI.to_string(%{uri | query: URI.encode_query(query)}))
    |> halt()
  end

  defp render_error(conn, message) do
    conn
    |> put_status(:bad_request)
    |> render("error.html", title: "Unable to connect", message: message)
    |> halt()
  end
end
