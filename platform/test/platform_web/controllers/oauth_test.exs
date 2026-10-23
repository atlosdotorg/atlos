defmodule PlatformWeb.OAuthTest do
  use PlatformWeb.ConnCase

  import Phoenix.LiveViewTest

  import Platform.AccountsFixtures
  import Platform.MaterialFixtures
  import Platform.ProjectsFixtures

  alias Platform.OAuth
  alias Platform.Projects
  alias Platform.Repo

  @redirect_uri "https://client.example.com/callback"
  @verifier String.duplicate("v", 50)

  defp challenge(verifier \\ @verifier),
    do: :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

  defp register_client(redirect_uris \\ [@redirect_uri]) do
    response =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post(
        "/oauth/register",
        Jason.encode!(%{client_name: "Test Client", redirect_uris: redirect_uris})
      )
      |> json_response(201)

    response["client_id"]
  end

  defp authorize_params(client_id, overrides \\ %{}) do
    Map.merge(
      %{
        "response_type" => "code",
        "client_id" => client_id,
        "redirect_uri" => @redirect_uri,
        "code_challenge" => challenge(),
        "code_challenge_method" => "S256",
        "state" => "xyz",
        "resource" => PlatformWeb.Endpoint.url() <> "/mcp"
      },
      overrides
    )
  end

  defp redirect_query(conn) do
    location = redirected_to(conn)
    {location, URI.decode_query(URI.parse(location).query || "")}
  end

  # Runs the consent flow as `user` and returns the authorization code.
  defp approve(user, client_id, project, access \\ "edit", overrides \\ %{}) do
    conn =
      build_conn()
      |> log_in_user(user)
      |> post(
        "/oauth/authorize",
        authorize_params(client_id, overrides)
        |> Map.merge(%{"decision" => "approve", "project_id" => project.id, "access" => access})
      )

    {location, query} = redirect_query(conn)
    assert String.starts_with?(location, @redirect_uri)
    assert query["state"] == "xyz"
    assert query["iss"] == PlatformWeb.Endpoint.url()
    query["code"]
  end

  defp exchange(client_id, code, verifier \\ @verifier) do
    build_conn()
    |> post("/oauth/token", %{
      "grant_type" => "authorization_code",
      "client_id" => client_id,
      "code" => code,
      "redirect_uri" => @redirect_uri,
      "code_verifier" => verifier
    })
  end

  defp connect_client(user, project, access \\ "edit") do
    client_id = register_client()
    code = approve(user, client_id, project, access)
    tokens = json_response(exchange(client_id, code), 200)
    {client_id, tokens}
  end

  defp member(project, role) do
    user = user_fixture()

    {:ok, _} =
      Projects.create_project_membership(%{
        project_id: project.id,
        username: user.username,
        role: role
      })

    user
  end

  defp rpc(access_token, method, params) do
    build_conn()
    |> put_req_header("authorization", "Bearer " <> access_token)
    |> put_req_header("content-type", "application/json")
    |> post("/mcp", Jason.encode!(%{jsonrpc: "2.0", id: 1, method: method, params: params}))
  end

  defp tool_names(access_token) do
    json_response(rpc(access_token, "tools/list", %{}), 200)["result"]["tools"]
    |> Enum.map(& &1["name"])
  end

  defp call_tool(access_token, name, arguments) do
    json_response(rpc(access_token, "tools/call", %{name: name, arguments: arguments}), 200)[
      "result"
    ]
  end

  describe "discovery" do
    test "unauthenticated MCP requests point at the protected resource metadata" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/json")
        |> post("/mcp", Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "ping"}))

      assert json_response(conn, 401)
      [challenge] = get_resp_header(conn, "www-authenticate")

      assert challenge =~
               "resource_metadata=\"#{PlatformWeb.Endpoint.url()}/.well-known/oauth-protected-resource/mcp\""
    end

    test "metadata documents describe the authorization server" do
      resource =
        json_response(get(build_conn(), "/.well-known/oauth-protected-resource/mcp"), 200)

      assert resource["resource"] == PlatformWeb.Endpoint.url() <> "/mcp"
      assert resource["authorization_servers"] == [PlatformWeb.Endpoint.url()]

      server = json_response(get(build_conn(), "/.well-known/oauth-authorization-server"), 200)
      assert server["issuer"] == PlatformWeb.Endpoint.url()
      assert server["code_challenge_methods_supported"] == ["S256"]
      assert server["registration_endpoint"] == PlatformWeb.Endpoint.url() <> "/oauth/register"
    end
  end

  describe "client registration" do
    test "accepts https, loopback, and reverse-domain redirect URIs" do
      assert is_binary(
               register_client([
                 @redirect_uri,
                 "http://localhost:3000/callback",
                 "com.example.app:/callback",
                 "cursor://anysphere.cursor-retrieval/oauth/callback"
               ])
             )
    end

    test "rejects unsafe redirect URIs" do
      for uri <- [
            "http://evil.example.com/cb",
            "javascript:alert(1)",
            "data:text/html,hi",
            "file:///etc/passwd",
            "https://x.example.com/#f"
          ] do
        conn =
          build_conn()
          |> put_req_header("content-type", "application/json")
          |> post("/oauth/register", Jason.encode!(%{client_name: "x", redirect_uris: [uri]}))

        assert json_response(conn, 400)["error"] == "invalid_redirect_uri"
      end
    end
  end

  describe "authorization" do
    test "requires signing in" do
      client_id = register_client()
      conn = get(build_conn(), "/oauth/authorize", authorize_params(client_id))
      assert redirected_to(conn) == "/users/log_in"
    end

    test "shows an error page, without redirecting, for unknown clients and redirect URIs" do
      user = user_fixture()
      client_id = register_client()

      conn =
        build_conn() |> log_in_user(user) |> get("/oauth/authorize", authorize_params("nope"))

      assert html_response(conn, 400) =~ "isn&#39;t registered"

      conn =
        build_conn()
        |> log_in_user(user)
        |> get(
          "/oauth/authorize",
          authorize_params(client_id, %{"redirect_uri" => "https://evil.example.com/cb"})
        )

      assert html_response(conn, 400) =~ "redirect address"
    end

    test "redirects other request errors back to the client" do
      user = user_fixture()
      client_id = register_client()

      conn =
        build_conn()
        |> log_in_user(user)
        |> get("/oauth/authorize", authorize_params(client_id, %{"code_challenge" => ""}))

      {_, query} = redirect_query(conn)
      assert query["error"] == "invalid_request"
      assert query["state"] == "xyz"

      conn =
        build_conn()
        |> log_in_user(user)
        |> get(
          "/oauth/authorize",
          authorize_params(client_id, %{"resource" => "https://elsewhere.example.com/mcp"})
        )

      {_, query} = redirect_query(conn)
      assert query["error"] == "invalid_target"
    end

    test "lists the projects the user can connect, excluding data-only viewer memberships" do
      user = user_fixture()
      project = project_fixture(%{name: "Connectable Project"}, owner: user)

      data_only_project = project_fixture(%{name: "Data Only Project", code: "code2"})

      {:ok, _} =
        Projects.create_project_membership(%{
          project_id: data_only_project.id,
          username: user.username,
          role: :data_only_viewer
        })

      client_id = register_client()

      html =
        build_conn()
        |> log_in_user(user)
        |> get("/oauth/authorize", authorize_params(client_id))
        |> html_response(200)

      assert html =~ "Test Client"
      assert html =~ "Connectable Project"
      refute html =~ "Data Only Project"
      assert html =~ "client.example.com"

      # Approving for the data-only project is refused
      conn =
        build_conn()
        |> log_in_user(user)
        |> post(
          "/oauth/authorize",
          authorize_params(client_id)
          |> Map.merge(%{"decision" => "approve", "project_id" => data_only_project.id})
        )

      assert redirected_to(conn) =~ "/oauth/authorize?"
      assert project.id
    end

    test "denying redirects with access_denied" do
      user = user_fixture()
      project_fixture(%{}, owner: user)
      client_id = register_client()

      conn =
        build_conn()
        |> log_in_user(user)
        |> post("/oauth/authorize", authorize_params(client_id) |> Map.put("decision", "deny"))

      {_, query} = redirect_query(conn)
      assert query["error"] == "access_denied"
      refute query["code"]
    end
  end

  describe "token endpoint" do
    test "requires the right PKCE verifier and redirect URI, and codes are single use" do
      user = user_fixture()
      project = project_fixture(%{}, owner: user)
      client_id = register_client()

      code = approve(user, client_id, project)

      assert json_response(exchange(client_id, code, String.duplicate("w", 50)), 400)["error"] ==
               "invalid_grant"

      # The failed attempt consumed the code
      assert json_response(exchange(client_id, code), 400)["error"] == "invalid_grant"

      code = approve(user, client_id, project)
      tokens = json_response(exchange(client_id, code), 200)
      assert tokens["token_type"] == "Bearer"
      assert tokens["scope"] == "read comment edit"
      assert tokens["expires_in"] == 3600

      assert {:ok, _, _} = OAuth.authenticate_access_token(tokens["access_token"])

      # Replaying the code fails and revokes the grant it produced
      assert json_response(exchange(client_id, code), 400)["error"] == "invalid_grant"
      assert OAuth.authenticate_access_token(tokens["access_token"]) == :error
    end

    test "codes are bound to the client that requested them" do
      user = user_fixture()
      project = project_fixture(%{}, owner: user)
      client_id = register_client()
      other_client_id = register_client()

      code = approve(user, client_id, project)
      assert json_response(exchange(other_client_id, code), 400)["error"] == "invalid_grant"
      assert json_response(exchange(client_id, code), 200)["access_token"]
    end

    test "loopback redirect URIs may use any port" do
      user = user_fixture()
      project = project_fixture(%{}, owner: user)
      client_id = register_client(["http://127.0.0.1/callback"])

      conn =
        build_conn()
        |> log_in_user(user)
        |> post(
          "/oauth/authorize",
          authorize_params(client_id, %{"redirect_uri" => "http://127.0.0.1:49152/callback"})
          |> Map.merge(%{"decision" => "approve", "project_id" => project.id})
        )

      assert redirected_to(conn) =~ "http://127.0.0.1:49152/callback?"
    end

    test "refreshing rotates both tokens" do
      user = user_fixture()
      project = project_fixture(%{}, owner: user)
      {client_id, tokens} = connect_client(user, project)

      refresh = fn refresh_token, extra ->
        build_conn()
        |> post(
          "/oauth/token",
          Map.merge(
            %{
              "grant_type" => "refresh_token",
              "client_id" => client_id,
              "refresh_token" => refresh_token
            },
            extra
          )
        )
      end

      new_tokens = json_response(refresh.(tokens["refresh_token"], %{}), 200)
      assert new_tokens["access_token"] != tokens["access_token"]

      assert OAuth.authenticate_access_token(tokens["access_token"]) == :error
      assert {:ok, _, _} = OAuth.authenticate_access_token(new_tokens["access_token"])

      assert json_response(refresh.(tokens["refresh_token"], %{}), 400)["error"] ==
               "invalid_grant"

      # Scopes can be narrowed, but not widened
      narrowed = json_response(refresh.(new_tokens["refresh_token"], %{"scope" => "read"}), 200)
      assert narrowed["scope"] == "read"

      assert json_response(refresh.(narrowed["refresh_token"], %{"scope" => "read edit"}), 400)[
               "error"
             ] == "invalid_scope"
    end

    test "revocation disables the grant" do
      user = user_fixture()
      project = project_fixture(%{}, owner: user)
      {_client_id, tokens} = connect_client(user, project)

      assert json_response(rpc(tokens["access_token"], "ping", %{}), 200)

      build_conn()
      |> post("/oauth/revoke", %{"token" => tokens["refresh_token"]})
      |> json_response(200)

      assert json_response(rpc(tokens["access_token"], "ping", %{}), 401)
    end
  end

  describe "MCP access as a user" do
    test "acts as the user, scoped to the authorized project" do
      user = user_fixture()
      project = project_fixture(%{}, owner: user)
      other_project = project_fixture(%{code: "code2"}, owner: user)
      media = media_fixture(%{project_id: project.id})
      other_media = media_fixture(%{project_id: other_project.id})

      {_client_id, tokens} = connect_client(user, project)
      token = tokens["access_token"]

      assert "create_incident" in tool_names(token)

      result = call_tool(token, "get_incident", %{slug: media.slug})
      assert result["isError"] == false

      result = call_tool(token, "get_incident", %{slug: other_media.slug})
      assert result["isError"] == true

      result = call_tool(token, "add_comment", %{slug: media.slug, message: "Hello from MCP"})
      assert result["isError"] == false

      comment =
        Platform.Updates.get_updates_for_media(media)
        |> Enum.find(&(&1.explanation == "Hello from MCP"))

      assert comment.user_id == user.id
      assert is_nil(comment.api_token_id)

      result =
        call_tool(token, "create_incident", %{
          description: "Incident created through OAuth",
          sensitive: ["Not Sensitive"]
        })

      assert result["isError"] == false, inspect(result)
      slug = result["structuredContent"]["incident"]["slug"]
      created = Platform.Material.get_full_media_by_slug(slug)
      assert created.project_id == project.id
    end

    test "read-only access lists only read tools" do
      user = user_fixture()
      project = project_fixture(%{}, owner: user)
      {_client_id, tokens} = connect_client(user, project, "read")

      assert tokens["scope"] == "read"
      names = tool_names(tokens["access_token"])
      assert "search_incidents" in names
      refute "add_comment" in names
      refute "create_incident" in names
    end

    test "viewers can read and comment but not edit, and can't see hidden incidents" do
      owner = user_fixture()
      project = project_fixture(%{}, owner: owner)
      viewer = member(project, :viewer)
      visible = media_fixture(%{project_id: project.id})

      hidden =
        media_fixture(%{project_id: project.id})
        |> Ecto.Changeset.change(attr_restrictions: ["Hidden"])
        |> Repo.update!()

      {_client_id, tokens} = connect_client(viewer, project, "edit")
      token = tokens["access_token"]

      # The viewer asked for edit access, but their role caps it
      assert tokens["scope"] == "read comment"
      names = tool_names(token)
      assert "add_comment" in names
      refute "update_incident_attribute" in names

      assert call_tool(token, "get_incident", %{slug: hidden.slug})["isError"] == true
      assert call_tool(token, "get_incident", %{slug: visible.slug})["isError"] == false

      slugs =
        call_tool(token, "search_incidents", %{})["structuredContent"]["results"]
        |> Enum.map(& &1["slug"])

      assert Platform.Material.Media.slug_to_display(visible) in slugs
      refute Platform.Material.Media.slug_to_display(hidden) in slugs
    end

    test "access follows the user's current role and membership" do
      owner = user_fixture()
      project = project_fixture(%{}, owner: owner)
      editor = member(project, :editor)

      {_client_id, tokens} = connect_client(editor, project)
      token = tokens["access_token"]
      assert "update_incident_attribute" in tool_names(token)

      membership = Projects.get_project_membership_by_user_and_project(editor, project)
      {:ok, _} = Projects.update_project_membership(membership, %{role: :viewer})
      Memoize.invalidate()

      refute "update_incident_attribute" in tool_names(token)

      {:ok, _} = Projects.delete_project_membership(membership)
      Memoize.invalidate()

      assert json_response(rpc(token, "ping", %{}), 401)
    end

    test "owners and managers can change restricted attributes; editors can't" do
      owner = user_fixture()
      project = project_fixture(%{}, owner: owner)
      manager = member(project, :manager)
      editor = member(project, :editor)
      media = media_fixture(%{project_id: project.id})

      args = %{
        slug: media.slug,
        attribute: "restrictions",
        value: ["Frozen"],
        message: "Freezing while we verify"
      }

      {_client_id, tokens} = connect_client(editor, project)
      result = call_tool(tokens["access_token"], "update_incident_attribute", args)
      assert result["isError"] == true

      {_client_id, tokens} = connect_client(manager, project)
      result = call_tool(tokens["access_token"], "update_incident_attribute", args)
      assert result["isError"] == false, inspect(result)
      assert Platform.Material.get_media!(media.id).attr_restrictions == ["Frozen"]
    end

    test "users can list and revoke their grants" do
      user = user_fixture()
      project = project_fixture(%{}, owner: user)
      {_client_id, tokens} = connect_client(user, project)

      [grant] = OAuth.list_active_grants(user)
      assert grant.client.client_name == "Test Client"

      assert OAuth.revoke_user_grant(user_fixture(), grant.id) == {:error, :not_found}
      assert OAuth.revoke_user_grant(user, grant.id) == :ok
      assert OAuth.list_active_grants(user) == []
      assert json_response(rpc(tokens["access_token"], "ping", %{}), 401)
    end
  end

  describe "when MCP is disabled" do
    setup do
      System.put_env("MCP_ENABLED", "false")
      on_exit(fn -> System.put_env("MCP_ENABLED", "true") end)
    end

    test "the MCP endpoint and every OAuth route return 404" do
      user = user_fixture()
      project = project_fixture(%{}, owner: user)
      token = Platform.APIFixtures.api_token_fixture(%{project_id: project.id})

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer " <> token.value)
        |> put_req_header("content-type", "application/json")
        |> post("/mcp", Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "ping"}))

      assert response(conn, 404)

      assert response(get(build_conn(), "/.well-known/oauth-protected-resource/mcp"), 404)
      assert response(get(build_conn(), "/.well-known/oauth-authorization-server"), 404)
      assert response(post(build_conn(), "/oauth/register", %{}), 404)
      assert response(post(build_conn(), "/oauth/token", %{}), 404)
      assert response(post(build_conn(), "/oauth/revoke", %{}), 404)

      assert response(build_conn() |> log_in_user(user) |> get("/oauth/authorize"), 404)
    end

    test "settings don't show connected apps" do
      user = user_fixture()
      {:ok, _view, html} = build_conn() |> log_in_user(user) |> live("/settings")
      refute html =~ "Connected Apps"

      System.put_env("MCP_ENABLED", "true")
      {:ok, _view, html} = build_conn() |> log_in_user(user) |> live("/settings")
      assert html =~ "Connected Apps"
    end
  end
end
