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
  defp approve(user, client_id, access \\ "edit", overrides \\ %{}) do
    conn =
      build_conn()
      |> log_in_user(user)
      |> post(
        "/oauth/authorize",
        authorize_params(client_id, overrides)
        |> Map.merge(%{"decision" => "approve", "access" => access})
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

  defp connect_client(user, access \\ "edit") do
    client_id = register_client()
    code = approve(user, client_id, access)
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

  defp member_as(project, user, role) do
    {:ok, _} =
      Projects.create_project_membership(%{
        project_id: project.id,
        username: user.username,
        role: role
      })
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

    test "lists the projects the client will reach, excluding data-only viewer memberships" do
      user = user_fixture()
      project_fixture(%{name: "Connectable Project"}, owner: user)

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
      assert html =~ "Read, comment, edit"
      refute html =~ "Data Only Project"
      assert html =~ "client.example.com"
      assert html =~ "Read, comment, and edit"
    end

    test "shows what the client can do in each project, for each access level" do
      user = user_fixture()
      project_fixture(%{name: "Owned Project"}, owner: user)
      viewed = project_fixture(%{name: "Viewed Project", code: "code2"})
      member_as(viewed, user, :viewer)

      html =
        build_conn()
        |> log_in_user(user)
        |> get("/oauth/authorize", authorize_params(register_client()))
        |> html_response(200)

      {:ok, document} = Floki.parse_document(html)

      rows =
        Floki.find(document, "li")
        |> Enum.map(fn row ->
          name = row |> Floki.find("span.text-neutral-800") |> Floki.text()

          labels =
            row
            |> Floki.find("span[x-show]")
            |> Enum.map(&{Floki.attribute(&1, "x-show") |> hd(), Floki.text(&1) |> String.trim()})
            |> Map.new()

          {name, labels}
        end)
        |> Map.new()

      assert rows["Owned Project"] == %{
               "access === 'edit'" => "Read, comment, edit",
               "access === 'comment'" => "Read, comment",
               "access === 'read'" => "Read only"
             }

      assert rows["Viewed Project"]["access === 'edit'"] == "Read, comment"
      assert html =~ "Viewer"
    end

    test "only offers the access the user's roles allow, and needs a project" do
      viewer = member(project_fixture(), :viewer)
      client_id = register_client()

      html =
        build_conn()
        |> log_in_user(viewer)
        |> get("/oauth/authorize", authorize_params(client_id))
        |> html_response(200)

      assert html =~ "Read and comment"
      refute html =~ "Read, comment, and edit"

      # Someone with no projects can't connect
      conn =
        build_conn()
        |> log_in_user(user_fixture())
        |> post("/oauth/authorize", authorize_params(client_id) |> Map.put("decision", "approve"))

      assert redirected_to(conn) =~ "/oauth/authorize?"
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
      project_fixture(%{}, owner: user)
      client_id = register_client()

      code = approve(user, client_id)

      assert json_response(exchange(client_id, code, String.duplicate("w", 50)), 400)["error"] ==
               "invalid_grant"

      # The failed attempt consumed the code
      assert json_response(exchange(client_id, code), 400)["error"] == "invalid_grant"

      code = approve(user, client_id)
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
      project_fixture(%{}, owner: user)
      client_id = register_client()
      other_client_id = register_client()

      code = approve(user, client_id)
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
      project_fixture(%{}, owner: user)
      {client_id, tokens} = connect_client(user)

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
      project_fixture(%{}, owner: user)
      {_client_id, tokens} = connect_client(user)

      assert json_response(rpc(tokens["access_token"], "ping", %{}), 200)

      build_conn()
      |> post("/oauth/revoke", %{"token" => tokens["refresh_token"]})
      |> json_response(200)

      assert json_response(rpc(tokens["access_token"], "ping", %{}), 401)
    end
  end

  describe "MCP access as a user" do
    test "acts as the user across their projects, and only their projects" do
      user = user_fixture()
      project = project_fixture(%{name: "Alpha"}, owner: user)
      other_project = project_fixture(%{name: "Beta", code: "code2"}, owner: user)
      stranger_project = project_fixture(%{code: "code3"})
      media = media_fixture(%{project_id: project.id})
      other_media = media_fixture(%{project_id: other_project.id})
      stranger_media = media_fixture(%{project_id: stranger_project.id})

      {_client_id, tokens} = connect_client(user)
      token = tokens["access_token"]

      assert "create_incident" in tool_names(token)

      projects = call_tool(token, "list_projects", %{})["structuredContent"]["projects"]
      assert Enum.map(projects, & &1["name"]) == ["Alpha", "Beta"]
      assert hd(projects)["permissions"] == ["read", "comment", "edit"]

      assert call_tool(token, "get_incident", %{slug: media.slug})["isError"] == false
      assert call_tool(token, "get_incident", %{slug: other_media.slug})["isError"] == false
      assert call_tool(token, "get_incident", %{slug: stranger_media.slug})["isError"] == true

      # Search covers every project the user can reach, or just one
      slugs = fn args ->
        call_tool(token, "search_incidents", args)["structuredContent"]["results"]
        |> Enum.map(& &1["slug"])
        |> MapSet.new()
      end

      display = &Platform.Material.Media.slug_to_display/1
      assert slugs.(%{}) == MapSet.new([display.(media), display.(other_media)])
      assert slugs.(%{project: other_project.id}) == MapSet.new([display.(other_media)])
      assert call_tool(token, "search_incidents", %{project: stranger_project.id})["isError"]

      result = call_tool(token, "add_comment", %{slug: media.slug, message: "Hello from MCP"})
      assert result["isError"] == false

      comment =
        Platform.Updates.get_updates_for_media(media)
        |> Enum.find(&(&1.explanation == "Hello from MCP"))

      assert comment.user_id == user.id
      assert is_nil(comment.api_token_id)

      incident = %{description: "Incident created through OAuth", sensitive: ["Not Sensitive"]}

      # With more than one project, create_incident needs to be told which
      result = call_tool(token, "create_incident", incident)
      assert result["isError"] == true
      assert hd(result["content"])["text"] =~ "project is required"

      result = call_tool(token, "create_incident", Map.put(incident, :project, other_project.id))
      assert result["isError"] == false, inspect(result)
      slug = result["structuredContent"]["incident"]["slug"]
      assert Platform.Material.get_full_media_by_slug(slug).project_id == other_project.id

      result =
        call_tool(token, "create_incident", Map.put(incident, :project, stranger_project.id))

      assert result["isError"] == true
    end

    test "permissions apply per project, following each role" do
      user = user_fixture()
      owned = project_fixture(%{name: "Owned"}, owner: user)
      viewed = project_fixture(%{name: "Viewed", code: "code2"})
      member_as(viewed, user, :viewer)
      owned_media = media_fixture(%{project_id: owned.id})
      viewed_media = media_fixture(%{project_id: viewed.id})

      {_client_id, tokens} = connect_client(user)
      token = tokens["access_token"]

      args = fn media ->
        %{slug: media.slug, attribute: "description", value: "A new description", message: "Fix"}
      end

      assert call_tool(token, "update_incident_attribute", args.(owned_media))["isError"] ==
               false

      assert call_tool(token, "update_incident_attribute", args.(viewed_media))["isError"] ==
               true

      assert call_tool(token, "add_comment", %{slug: viewed_media.slug, message: "Hi"})[
               "isError"
             ] == false

      assert call_tool(token, "create_incident", %{
               project: viewed.id,
               description: "Should not be created",
               sensitive: ["Not Sensitive"]
             })["isError"] == true

      viewed_entry =
        call_tool(token, "list_projects", %{})["structuredContent"]["projects"]
        |> Enum.find(&(&1["name"] == "Viewed"))

      assert viewed_entry["permissions"] == ["read", "comment"]
      assert viewed_entry["role"] == "viewer"
    end

    test "projects where the user is a data-only viewer are out of reach" do
      user = user_fixture()
      project_fixture(%{}, owner: user)
      data_only = project_fixture(%{code: "code2"})
      member_as(data_only, user, :data_only_viewer)
      media = media_fixture(%{project_id: data_only.id})

      {_client_id, tokens} = connect_client(user)
      token = tokens["access_token"]

      assert call_tool(token, "get_incident", %{slug: media.slug})["isError"] == true
      assert length(call_tool(token, "list_projects", %{})["structuredContent"]["projects"]) == 1
    end

    test "read-only access lists only read tools" do
      user = user_fixture()
      project_fixture(%{}, owner: user)
      {_client_id, tokens} = connect_client(user, "read")

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

      {_client_id, tokens} = connect_client(viewer, "edit")
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
      media = media_fixture(%{project_id: project.id})

      {_client_id, tokens} = connect_client(editor)
      token = tokens["access_token"]
      assert "update_incident_attribute" in tool_names(token)

      membership = Projects.get_project_membership_by_user_and_project(editor, project)
      {:ok, _} = Projects.update_project_membership(membership, %{role: :viewer})
      Memoize.invalidate()

      refute "update_incident_attribute" in tool_names(token)

      {:ok, _} = Projects.delete_project_membership(membership)
      Memoize.invalidate()

      # The connection still works, but the project is out of reach
      assert json_response(rpc(token, "ping", %{}), 200)
      assert call_tool(token, "get_incident", %{slug: media.slug})["isError"] == true
      assert call_tool(token, "list_projects", %{})["structuredContent"]["projects"] == []
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

      {_client_id, tokens} = connect_client(editor)
      result = call_tool(tokens["access_token"], "update_incident_attribute", args)
      assert result["isError"] == true

      {_client_id, tokens} = connect_client(manager)
      result = call_tool(tokens["access_token"], "update_incident_attribute", args)
      assert result["isError"] == false, inspect(result)
      assert Platform.Material.get_media!(media.id).attr_restrictions == ["Frozen"]
    end

    test "users can list and revoke their grants" do
      user = user_fixture()
      project_fixture(%{}, owner: user)
      {_client_id, tokens} = connect_client(user)

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
