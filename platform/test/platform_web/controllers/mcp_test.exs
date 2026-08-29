defmodule PlatformWeb.MCPTest do
  use PlatformWeb.ConnCase

  import Platform.APIFixtures
  import Platform.MaterialFixtures
  import Platform.ProjectsFixtures

  alias Platform.Material

  defp mcp_conn(token, body) do
    build_conn()
    |> put_req_header("authorization", "Bearer " <> token.value)
    |> put_req_header("content-type", "application/json")
    |> post("/mcp", Jason.encode!(body))
  end

  defp rpc(token, method, params, id \\ 1) do
    mcp_conn(token, %{jsonrpc: "2.0", id: id, method: method, params: params})
  end

  defp call_tool(token, name, arguments) do
    response = json_response(rpc(token, "tools/call", %{name: name, arguments: arguments}), 200)
    assert response["jsonrpc"] == "2.0"
    response
  end

  defp call_tool!(token, name, arguments) do
    response = call_tool(token, name, arguments)
    assert response["result"]["isError"] == false, inspect(response)
    response["result"]["structuredContent"]
  end

  defp tool_error(token, name, arguments) do
    response = call_tool(token, name, arguments)
    assert response["result"]["isError"] == true, inspect(response)
    response["result"]["content"] |> hd() |> Map.get("text")
  end

  test "authentication is required and project-scoped" do
    noauth_conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> post("/mcp", Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "ping"}))

    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    legacy_token = api_token_fixture_legacy()

    legacy_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> legacy_token.value)
      |> put_req_header("content-type", "application/json")
      |> post("/mcp", Jason.encode!(%{jsonrpc: "2.0", id: 1, method: "ping"}))

    assert json_response(legacy_conn, 401) == %{"error" => "invalid token or token not found"}
  end

  test "GET is rejected with 405" do
    project = project_fixture()
    token = api_token_fixture(%{project_id: project.id})

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> get("/mcp")

    assert json_response(conn, 405)
  end

  test "initialize, ping, and notifications" do
    project = project_fixture()
    token = api_token_fixture(%{project_id: project.id})

    response = json_response(rpc(token, "initialize", %{"protocolVersion" => "2025-03-26"}), 200)

    assert response["result"]["protocolVersion"] == "2025-03-26"
    assert response["result"]["serverInfo"]["name"] == "Atlos"
    assert is_binary(response["result"]["instructions"])

    # An unsupported requested version falls back to the server's default
    response = json_response(rpc(token, "initialize", %{"protocolVersion" => "1999-01-01"}), 200)

    assert response["result"]["protocolVersion"] == "2025-06-18"

    # Ping
    response = json_response(rpc(token, "ping", %{}), 200)
    assert response["result"] == %{}

    # Notifications are acknowledged with 202 and no body
    conn = mcp_conn(token, %{jsonrpc: "2.0", method: "notifications/initialized"})
    assert response(conn, 202) == ""
  end

  test "protocol errors: batches, unknown methods, malformed messages" do
    project = project_fixture()
    token = api_token_fixture(%{project_id: project.id})

    # Batches are not supported
    conn = mcp_conn(token, [%{jsonrpc: "2.0", id: 1, method: "ping"}])
    assert %{"error" => %{"code" => -32600}} = json_response(conn, 200)

    # Unknown method
    response = json_response(rpc(token, "resources/list", %{}), 200)
    assert %{"error" => %{"code" => -32601}} = response

    # Not JSON-RPC
    conn = mcp_conn(token, %{hello: "world"})
    assert %{"error" => %{"code" => -32600}} = json_response(conn, 200)
  end

  test "tools/list is filtered by token permissions" do
    project = project_fixture()

    read_token = api_token_fixture(%{project_id: project.id})
    comment_token = api_token_fixture(%{project_id: project.id, permissions: [:read, :comment]})

    edit_token =
      api_token_fixture(%{project_id: project.id, permissions: [:read, :comment, :edit]})

    names = fn token ->
      response = json_response(rpc(token, "tools/list", %{}), 200)
      response["result"]["tools"] |> Enum.map(& &1["name"]) |> Enum.sort()
    end

    read_tools = [
      "get_incident",
      "get_incident_updates",
      "get_project",
      "get_source_material",
      "search_incidents"
    ]

    assert names.(read_token) == read_tools
    assert names.(comment_token) == Enum.sort(read_tools ++ ["add_comment"])

    assert names.(edit_token) ==
             Enum.sort(
               read_tools ++
                 [
                   "add_comment",
                   "add_source_material",
                   "create_incident",
                   "update_incident_attribute"
                 ]
             )

    # Read tools carry readOnlyHint
    response = json_response(rpc(read_token, "tools/list", %{}), 200)

    for tool <- response["result"]["tools"] do
      assert tool["annotations"]["readOnlyHint"] == true
      assert is_map(tool["inputSchema"])
    end

    # Calling a tool the token can't see is a protocol error
    response =
      json_response(rpc(read_token, "tools/call", %{name: "add_comment", arguments: %{}}), 200)

    assert %{"error" => %{"code" => -32602}} = response
  end

  test "get_project returns attribute definitions" do
    project = project_fixture()
    token = api_token_fixture(%{project_id: project.id})

    %{"project" => result} = call_tool!(token, "get_project", %{})
    assert result["id"] == project.id
    assert result["code"] == project.code

    status = Enum.find(result["attributes"], &(&1["id"] == "status"))
    assert status["type"] == "select"
    assert Enum.member?(status["options"], "In Progress")

    impact_definition = project.attributes |> Enum.find(&(&1.name == "Impact"))
    impact = Enum.find(result["attributes"], &(&1["id"] == impact_definition.id))
    assert impact["is_custom"] == true

    restrictions = Enum.find(result["attributes"], &(&1["id"] == "restrictions"))
    assert restrictions["is_restricted"] == true
  end

  test "search_incidents is scoped, filterable, and paginated" do
    project = project_fixture()
    other_project = project_fixture()
    token = api_token_fixture(%{project_id: project.id})

    media = media_fixture(%{project_id: project.id})
    media_fixture(%{project_id: other_project.id})

    %{"results" => results, "cursor" => nil} = call_tool!(token, "search_incidents", %{})
    assert length(results) == 1
    assert hd(results)["id"] == media.id
    assert is_binary(hd(results)["url"])
    assert String.contains?(hd(results)["slug"], project.code)

    # Filtering by status
    %{"results" => results} =
      call_tool!(token, "search_incidents", %{"status" => ["In Progress"]})

    assert results == []

    %{"results" => results} = call_tool!(token, "search_incidents", %{"status" => ["To Do"]})
    assert length(results) == 1

    # Invalid search parameters produce a tool error
    error = tool_error(token, "search_incidents", %{"sort" => "bogus"})
    assert error =~ "sort"

    # Pagination: create enough incidents for several pages
    Enum.each(1..30, fn _ -> media_fixture(%{project_id: project.id}) end)

    %{"results" => page_one, "cursor" => cursor} = call_tool!(token, "search_incidents", %{})
    assert length(page_one) == 25
    assert is_binary(cursor)

    %{"results" => page_two, "cursor" => nil} =
      call_tool!(token, "search_incidents", %{"cursor" => cursor})

    assert length(page_two) == 6

    ids = Enum.map(page_one ++ page_two, & &1["id"])
    assert length(Enum.uniq(ids)) == 31

    # A garbage cursor is a tool error
    error = tool_error(token, "search_incidents", %{"cursor" => "garbage"})
    assert error =~ "cursor"
  end

  test "get_incident accepts raw and display slugs and is project-scoped" do
    project = project_fixture()
    other_project = project_fixture()
    token = api_token_fixture(%{project_id: project.id})

    media = media_fixture(%{project_id: project.id})
    other_media = media_fixture(%{project_id: other_project.id})

    result = call_tool!(token, "get_incident", %{"slug" => media.slug})
    assert result["incident"]["id"] == media.id

    assert result["slug"] ==
             Material.Media.slug_to_display(Material.get_full_media_by_slug(media.slug))

    # Display form (CODE-SLUG) also resolves
    display_slug = result["slug"]
    result = call_tool!(token, "get_incident", %{"slug" => display_slug})
    assert result["incident"]["id"] == media.id

    # Another project's incident is not visible
    error = tool_error(token, "get_incident", %{"slug" => other_media.slug})
    assert error =~ "not found"

    error = tool_error(token, "get_incident", %{"slug" => "NOPE-123"})
    assert error =~ "not found"
  end

  test "add_comment and get_incident_updates" do
    project = project_fixture()
    token = api_token_fixture(%{project_id: project.id, permissions: [:read, :comment]})
    read_token = api_token_fixture(%{project_id: project.id})

    media = media_fixture(%{project_id: project.id})

    assert %{"success" => true} =
             call_tool!(token, "add_comment", %{"slug" => media.slug, "message" => "mcp comment"})

    assert length(Platform.Updates.list_updates()) == 1

    %{"results" => results, "cursor" => nil} =
      call_tool!(token, "get_incident_updates", %{"slug" => media.slug})

    assert length(results) == 1
    assert hd(results)["explanation"] == "mcp comment"
    assert hd(results)["api_token_id"] == token.id

    # Blank messages are rejected
    error = tool_error(token, "add_comment", %{"slug" => media.slug, "message" => ""})
    assert error =~ "message"

    # A read-only token cannot see the tool at all
    response =
      json_response(
        rpc(read_token, "tools/call", %{
          name: "add_comment",
          arguments: %{"slug" => media.slug, "message" => "nope"}
        }),
        200
      )

    assert %{"error" => %{"code" => -32602}} = response
  end

  test "create_incident with core and project-defined attributes" do
    project = project_fixture()
    token = api_token_fixture(%{project_id: project.id, permissions: [:read, :comment, :edit]})

    impact_definition = project.attributes |> Enum.find(&(&1.name == "Impact"))

    %{"incident" => incident} =
      call_tool!(token, "create_incident", %{
        "description" => "Test MCP incident description",
        "sensitive" => ["Not Sensitive"],
        "attributes" => %{impact_definition.id => impact_definition.options}
      })

    assert incident["description"] == "Test MCP incident description"
    assert is_binary(incident["slug"])

    media = Material.get_media!(incident["id"])
    assert media.attr_description == "Test MCP incident description"

    assert (media.project_attributes
            |> Enum.find(&(&1.id == impact_definition.id))).value == impact_definition.options

    # Unknown attributes are named in the error
    error =
      tool_error(token, "create_incident", %{
        "description" => "Test MCP incident description",
        "sensitive" => ["Not Sensitive"],
        "attributes" => %{"bogus_attribute" => "value"}
      })

    assert error =~ "bogus_attribute"

    # Changeset validation errors are surfaced
    error =
      tool_error(token, "create_incident", %{
        "description" => "short",
        "sensitive" => ["Not Sensitive"]
      })

    assert error =~ "at least 8"
  end

  test "update_incident_attribute updates core and custom attributes, refuses restricted ones" do
    project = project_fixture()
    token = api_token_fixture(%{project_id: project.id, permissions: [:read, :comment, :edit]})
    media = media_fixture(%{project_id: project.id})

    assert %{"success" => true} =
             call_tool!(token, "update_incident_attribute", %{
               "slug" => media.slug,
               "attribute" => "description",
               "value" => "an updated description",
               "message" => "updating via MCP"
             })

    assert Material.get_media!(media.id).attr_description == "an updated description"

    # The explanation lands on the activity feed
    update = Platform.Updates.list_updates() |> List.last()
    assert update.explanation == "updating via MCP"
    assert update.api_token_id == token.id

    # Custom attribute by UUID
    impact_definition = project.attributes |> Enum.find(&(&1.name == "Impact"))

    assert %{"success" => true} =
             call_tool!(token, "update_incident_attribute", %{
               "slug" => media.slug,
               "attribute" => impact_definition.id,
               "value" => impact_definition.options,
               "message" => "setting impact"
             })

    # A message is required
    error =
      tool_error(token, "update_incident_attribute", %{
        "slug" => media.slug,
        "attribute" => "description",
        "value" => "another description"
      })

    assert error =~ "message"

    # Restricted attributes are refused
    error =
      tool_error(token, "update_incident_attribute", %{
        "slug" => media.slug,
        "attribute" => "restrictions",
        "value" => ["Frozen"],
        "message" => "freezing"
      })

    assert error =~ "restricted"

    # Unknown attributes point at get_project
    error =
      tool_error(token, "update_incident_attribute", %{
        "slug" => media.slug,
        "attribute" => "bogus",
        "value" => "x",
        "message" => "y"
      })

    assert error =~ "get_project"
  end

  test "add_source_material and get_source_material" do
    project = project_fixture()
    other_project = project_fixture()
    token = api_token_fixture(%{project_id: project.id, permissions: [:read, :comment, :edit]})
    other_token = api_token_fixture(%{project_id: other_project.id})

    media = media_fixture(%{project_id: project.id})

    %{"source_material" => version} =
      call_tool!(token, "add_source_material", %{
        "slug" => media.slug,
        "url" => "https://atlos.org"
      })

    assert version["source_url"] == "https://atlos.org"
    assert version["upload_type"] == "user_provided"

    %{"source_material" => archived} =
      call_tool!(token, "add_source_material", %{
        "slug" => media.slug,
        "url" => "https://atlos.org",
        "archive" => true
      })

    assert archived["upload_type"] == "direct"

    # Fetch one back
    %{"source_material" => fetched} =
      call_tool!(token, "get_source_material", %{"id" => version["id"]})

    assert fetched["id"] == version["id"]

    # Not visible from another project's token
    error = tool_error(other_token, "get_source_material", %{"id" => version["id"]})
    assert error =~ "not found"

    # Invalid UUIDs are handled gracefully
    error = tool_error(token, "get_source_material", %{"id" => "not-a-uuid"})
    assert error =~ "not found"
  end
end
