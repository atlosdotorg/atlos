defmodule PlatformWeb.APIV2Test do
  use PlatformWeb.ConnCase
  import Platform.APIFixtures
  import Platform.MaterialFixtures
  import Platform.ProjectsFixtures
  alias Platform.Material

  test "GET /api/v2/incidents", %{conn: conn} do
    noauth_conn = get(conn, "/api/v2/incidents")
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    noauth_conn = get(put_req_header(conn, "authorization", "Bearer "), "/api/v2/incidents")
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    noauth_conn = get(put_req_header(conn, "authorization", "Bearer bad"), "/api/v2/incidents")
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    project = project_fixture()
    legacy_token = api_token_fixture_legacy()
    token = api_token_fixture(%{project_id: project.id})

    # Ensure legacy tokens can't connect to v2
    noauth_conn =
      get(
        put_req_header(conn, "authorization", "Bearer " <> legacy_token.value),
        "/api/v2/incidents"
      )

    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    # Ensure new tokens can't connect to v1
    noauth_conn =
      get(put_req_header(conn, "authorization", "Bearer " <> token.value), "/api/v1/media")

    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> get("/api/v2/incidents")

    assert json_response(auth_conn, 200) == %{"results" => [], "previous" => nil, "next" => nil}

    media = media_fixture(%{project_id: project.id})

    # Create a second incident that should *not* show up in the results
    other_project = project_fixture()
    media_fixture(%{project_id: other_project.id})

    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> get("/api/v2/incidents")

    assert json_response(auth_conn, 200) == %{
             # Manually fetch since the database will change certain values
             "results" => [
               Jason.decode!(Jason.encode!(Material.get_media!(media.id)))
             ],
             "previous" => nil,
             "next" => nil
           }
  end

  test "GET /api/v2/incidents with pagination" do
    n = 1501
    project = project_fixture()

    other_project = project_fixture()

    Enum.map(0..(n - 1), fn _ -> media_fixture(%{project_id: project.id}) end)
    Enum.map(0..(n - 1), fn _ -> media_fixture(%{project_id: other_project.id}) end)

    token = api_token_fixture(%{project_id: project.id})

    {media, final_next} =
      Enum.reduce(0..(ceil(n / 50) + 25), {[], :start}, fn _, {elems, next} ->
        if not is_nil(next) do
          auth_conn =
            build_conn()
            |> put_req_header("authorization", "Bearer " <> token.value)
            |> get(
              if next != :start,
                do: "/api/v2/incidents?cursor=#{next}",
                else: "/api/v2/incidents"
            )

          %{"results" => results, "previous" => _prev, "next" => new_next} =
            json_response(auth_conn, 200)

          {elems ++ results, new_next}
        else
          {elems, nil}
        end
      end)

    media = media |> Enum.sort() |> Enum.dedup()

    assert length(media) == n
    assert final_next == nil
  end

  test "GET /api/v2/source_material", %{conn: conn} do
    noauth_conn = get(conn, "/api/v2/source_material")
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    project = project_fixture()
    token = api_token_fixture(%{project_id: project.id})

    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> get("/api/v2/source_material")

    assert json_response(auth_conn, 200) == %{"results" => [], "previous" => nil, "next" => nil}

    media = media_fixture(%{project_id: project.id})
    media_version_fixture(%{media_id: media.id})

    # Create a media version that should *not* show up in the results
    other_project = project_fixture()
    other_media = media_fixture(%{project_id: other_project.id})
    media_version_fixture(%{media_id: other_media.id})

    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> get("/api/v2/source_material")

    assert json_response(auth_conn, 200) == %{
             "results" =>
               Jason.decode!(
                 Jason.encode!(
                   Material.list_media_versions()
                   |> Enum.filter(&(&1.media.project_id == project.id))
                 )
               ),
             "previous" => nil,
             "next" => nil
           }
  end

  test "POST /api/v2/add_comment/:slug" do
    project = project_fixture()
    other_project = project_fixture()

    underpermissioned_token = api_token_fixture(%{project_id: project.id})
    token = api_token_fixture(%{project_id: project.id, permissions: [:read, :comment]})

    other_token =
      api_token_fixture(%{project_id: other_project.id, permissions: [:read, :comment]})

    media = media_fixture(%{project_id: project.id})
    media_fixture(%{project_id: other_project.id})

    noauth_conn = post(build_conn(), "/api/v2/add_comment/#{media.slug}", %{})
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    # This one should work
    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/add_comment/#{media.slug}", %{"message" => "test"})

    assert json_response(auth_conn, 200) == %{"success" => true}
    assert length(Platform.Updates.list_updates()) == 1

    # This one should fail because the token doesn't have the right permissions
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> underpermissioned_token.value)
      |> post("/api/v2/add_comment/#{media.slug}", %{"message" => "test"})

    assert json_response(conn, 401) == %{"error" => "api token not authorized to post comment"}

    # This one should fail because the media doesn't exist
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/add_comment/ABCDEFG", %{"message" => "test"})

    assert json_response(conn, 401) == %{"error" => "incident not found"}

    # This one should fail because the media is in the wrong project
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> other_token.value)
      |> post("/api/v2/add_comment/#{media.slug}", %{"message" => "test"})

    assert json_response(conn, 401) == %{"error" => "incident not found"}
  end

  test "POST /api/v2/update/:slug/:attribute" do
    project = project_fixture()
    other_project = project_fixture()

    underpermissioned_token =
      api_token_fixture(%{project_id: project.id, permissions: [:read, :comment]})

    token = api_token_fixture(%{project_id: project.id, permissions: [:read, :comment, :edit]})

    other_token =
      api_token_fixture(%{project_id: other_project.id, permissions: [:read, :comment, :edit]})

    media = media_fixture(%{project_id: project.id})
    media_fixture(%{project_id: other_project.id})

    noauth_conn = post(build_conn(), "/api/v2/update/#{media.slug}/description", %{})
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    # This one should work
    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/update/#{media.slug}/description", %{
        "message" => "test",
        "value" => "new description"
      })

    assert json_response(auth_conn, 200) == %{"success" => true}
    assert length(Platform.Updates.list_updates()) == 1
    assert Material.get_media!(media.id).attr_description == "new description"

    # As should this one (project attribute)
    project_attribute = project.attributes |> Enum.find(&(&1.name == "Impact"))

    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/update/#{media.slug}/#{project_attribute.id}", %{
        "message" => "test",
        "value" => project_attribute.options
      })

    assert json_response(auth_conn, 200) == %{"success" => true}
    assert length(Platform.Updates.list_updates()) == 2

    assert (Material.get_media!(media.id).project_attributes
            |> Enum.find(&(&1.id == project_attribute.id))).value == project_attribute.options

    # This one should fail because the token doesn't have the right permissions
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> underpermissioned_token.value)
      |> post("/api/v2/update/#{media.slug}/description", %{
        "message" => "test",
        "value" => "new description"
      })

    assert json_response(conn, 401) == %{"error" => "api token not authorized to edit"}

    # This one should fail because the media doesn't exist
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/update/ABCDEFG/description", %{
        "message" => "test",
        "value" => "new description"
      })

    assert json_response(conn, 401) == %{"error" => "incident not found"}

    # This one should fail because the media is in the wrong project
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> other_token.value)
      |> post("/api/v2/update/#{media.slug}/description", %{
        "message" => "test",
        "value" => "new description"
      })

    assert json_response(conn, 401) == %{"error" => "incident not found"}
  end
end
