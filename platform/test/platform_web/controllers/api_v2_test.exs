defmodule PlatformWeb.APIV2Test do
  alias Platform.Updates
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
        if is_nil(next) do
          {elems, nil}
        else
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
        end
      end)

    media = media |> Enum.sort() |> Enum.dedup()

    assert length(media) == n
    assert final_next == nil
  end

  test "GET /api/v2/updates with pagination" do
    n = 101
    project = project_fixture()

    other_project = project_fixture()

    Enum.map(0..(n - 1), fn _ ->
      m = media_fixture(%{project_id: project.id})
      {:ok, _} = Updates.post_bot_comment(m, "foo")
    end)

    Enum.map(0..(n - 1), fn _ ->
      m = media_fixture(%{project_id: other_project.id})
      {:ok, _} = Updates.post_bot_comment(m, "foo")
    end)

    token = api_token_fixture(%{project_id: project.id})

    {updates, final_next} =
      Enum.reduce(0..(ceil(n / 50) + 25), {[], :start}, fn _, {elems, next} ->
        if is_nil(next) do
          {elems, nil}
        else
          auth_conn =
            build_conn()
            |> put_req_header("authorization", "Bearer " <> token.value)
            |> get(
              if next != :start,
                do: "/api/v2/updates?cursor=#{next}",
                else: "/api/v2/updates"
            )

          %{"results" => results, "previous" => _prev, "next" => new_next} =
            json_response(auth_conn, 200)

          {elems ++ results, new_next}
        end
      end)

    updates = updates |> Enum.sort() |> Enum.dedup()

    assert length(updates) == n
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

  test "POST /api/v2/source_material/new/:slug" do
    project = project_fixture()
    other_project = project_fixture()

    underpermissioned_token =
      api_token_fixture(%{project_id: project.id, permissions: [:read, :comment]})

    token = api_token_fixture(%{project_id: project.id, permissions: [:read, :comment, :edit]})

    other_token =
      api_token_fixture(%{project_id: other_project.id, permissions: [:read, :comment, :edit]})

    media = media_fixture(%{project_id: project.id})
    media_fixture(%{project_id: other_project.id})

    noauth_conn = post(build_conn(), "/api/v2/source_material/new/#{media.slug}", %{})
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    # This one should work
    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/source_material/new/#{media.slug}", %{
        "url" => "https://atlos.org"
      })

    %{"success" => true, "result" => version} = json_response(auth_conn, 200)
    assert version["source_url"] == "https://atlos.org"
    assert version["upload_type"] == "user_provided"

    # Now verify the version was created
    new_material = Material.get_media!(media.id)
    version = new_material.versions |> Enum.find(&(&1.id == version["id"]))
    assert not is_nil(version)
    assert version.scoped_id == 1

    # Do it again, this time with archival
    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/source_material/new/#{media.slug}", %{
        "url" => "https://atlos.org",
        "archive" => "true"
      })

    %{"success" => true, "result" => version} = json_response(auth_conn, 200)
    assert version["source_url"] == "https://atlos.org"
    assert version["upload_type"] == "direct"
    assert version["scoped_id"] == 2
    # This one should fail because the token doesn't have the right permissions
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> underpermissioned_token.value)
      |> post("/api/v2/source_material/new/#{media.slug}", %{
        "url" => "https://atlos.org",
        "archive" => "true"
      })

    assert json_response(conn, 401) == %{"error" => "incident not found or unauthorized"}

    # This one should fail because the media doesn't exist
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/source_material/new/abcde", %{
        "url" => "https://atlos.org",
        "archive" => "true"
      })

    assert json_response(conn, 401) == %{"error" => "incident not found or unauthorized"}

    # This one should fail because the media is in the wrong project
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> other_token.value)
      |> post("/api/v2/source_material/new/#{media.slug}", %{
        "url" => "https://atlos.org",
        "archive" => "true"
      })

    assert json_response(conn, 401) == %{"error" => "incident not found or unauthorized"}
  end

  test "POST /source_material/metadata/:version_id/:namespace" do
    project = project_fixture()
    other_project = project_fixture()

    token = api_token_fixture(%{project_id: project.id, permissions: [:read, :comment, :edit]})

    media = media_fixture(%{project_id: project.id})
    media_fixture(%{project_id: other_project.id})

    # Create a media version
    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/source_material/new/#{media.slug}", %{
        "url" => "https://atlos.org"
      })

    %{"success" => true, "result" => version} = json_response(auth_conn, 200)

    version_id = version["id"]

    noauth_conn = post(build_conn(), "/api/v2/source_material/metadata/#{version_id}/test", %{})
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    metadata = %{
      "foo" => "bar",
      "abc" => [1, 2, 3]
    }

    # This one should work
    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/source_material/metadata/#{version_id}/test", %{
        "metadata" => metadata
      })

    %{"success" => true, "result" => version} = json_response(auth_conn, 200)
    assert version["metadata"]["test"] == metadata
  end

  test "POST /source_material/upload/:version_id" do
    # Make a temporary file to upload
    Temp.track!()
    {:ok, fd, file_path} = Temp.open("test-file")
    IO.write(fd, "some content for the file")
    File.close(fd)

    # Create a Plug upload struct
    upload = %Plug.Upload{
      content_type: "text/plain",
      filename: "test-file.txt",
      path: file_path
    }

    project = project_fixture()
    other_project = project_fixture()

    underpermissioned_token =
      api_token_fixture(%{project_id: project.id, permissions: [:read, :comment]})

    token = api_token_fixture(%{project_id: project.id, permissions: [:read, :comment, :edit]})

    other_token =
      api_token_fixture(%{project_id: other_project.id, permissions: [:read, :comment, :edit]})

    media = media_fixture(%{project_id: project.id})
    media_fixture(%{project_id: other_project.id})

    # Create a media version
    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/source_material/new/#{media.slug}", %{
        "url" => "https://atlos.org"
      })

    %{"success" => true, "result" => version} = json_response(auth_conn, 200)

    version_id = version["id"]

    # Quickly check that permission validation is working
    noauth_conn = post(build_conn(), "/api/v2/source_material/upload/#{version_id}", %{})
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> underpermissioned_token.value)
      |> post("/api/v2/source_material/upload/#{version_id}", %{})

    assert json_response(conn, 401) == %{"error" => "media version not found or unauthorized"}

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> other_token.value)
      |> post("/api/v2/source_material/upload/#{version_id}", %{})

    assert json_response(conn, 401) == %{"error" => "media version not found or unauthorized"}

    # Upload the file to the media version
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/source_material/upload/#{version_id}", %{
        "title" => "Example API Upload",
        "file" => upload
      })

    %{"success" => true, "result" => _} = json_response(conn, 200)
  end

  test "GET /source_material/:id" do
    project = project_fixture()
    other_project = project_fixture()

    token = api_token_fixture(%{project_id: project.id, permissions: [:read, :comment, :edit]})

    other_token =
      api_token_fixture(%{project_id: other_project.id, permissions: [:read, :comment, :edit]})

    media = media_fixture(%{project_id: project.id})
    media_fixture(%{project_id: other_project.id})

    # Create a media version
    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/source_material/new/#{media.slug}", %{
        "url" => "https://atlos.org"
      })

    %{"success" => true, "result" => version} = json_response(auth_conn, 200)

    version_id = version["id"]

    # Quickly check that permission validation is working
    noauth_conn = get(build_conn(), "/api/v2/source_material/#{version_id}", %{})
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> other_token.value)
      |> get("/api/v2/source_material/#{version_id}", %{})

    assert json_response(conn, 401) == %{"error" => "media version not found or unauthorized"}

    # Upload the file to the media version
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> get("/api/v2/source_material/#{version_id}")

    %{"success" => true, "result" => ^version} = json_response(conn, 200)
  end

  test "POST /incidents/new" do
    project = project_fixture()

    underpermissioned_token =
      api_token_fixture(%{project_id: project.id, permissions: [:read, :comment]})

    token = api_token_fixture(%{project_id: project.id, permissions: [:read, :comment, :edit]})

    # Create a piece of media
    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/incidents/new", %{
        "sensitive" => ["Not Sensitive"],
        "description" => "Test incident description"
      })

    %{"success" => true, "result" => media} = json_response(auth_conn, 200)
    assert media["attr_sensitive"] == ["Not Sensitive"]
    assert media["attr_description"] == "Test incident description"

    # Quickly check that permission validation is working
    noauth_conn = post(build_conn(), "/api/v2/incidents/new", %{})
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    # Check that underpermissioned tokens can't create incidents
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> underpermissioned_token.value)
      |> post("/api/v2/incidents/new", %{})

    assert json_response(conn, 401) == %{"error" => "unauthorized"}

    # Check that validation for required attributes is working pt. 1
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/incidents/new", %{
        "sensitive" => ["Not Sensitive"]
      })

    assert json_response(conn, 401) == %{"error" => %{"attr_description" => "can't be blank"}}

    # Check that validation for required attributes is working pt. 2
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/incidents/new", %{
        "description" => "Test incident name"
      })

    assert json_response(conn, 401) == %{"error" => %{"attr_sensitive" => "can't be blank"}}

    # Check that validation for required attributes is working pt. 3
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/incidents/new", %{})

    assert json_response(conn, 401) == %{
             "error" => %{
               "attr_description" => "can't be blank",
               "attr_sensitive" => "can't be blank"
             }
           }

    # Ensure length validation of required attributes is passed in API response
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/incidents/new", %{
        "description" => "Short",
        "sensitive" => ["Not Sensitive"]
      })

    assert json_response(conn, 401) == %{
             "error" => %{"attr_description" => "should be at least 8 character(s)"}
           }

    # Ensure type validation of required attributes is passed in API response
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/incidents/new", %{
        "description" => "Test incident description",
        "sensitive" => "Not Sensitive"
      })

    assert json_response(conn, 401) == %{
             "error" => %{"attr_sensitive" => "must be an array of strings"}
           }

    # Ensure type validation of optional attributes is passed in API response
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> post("/api/v2/incidents/new", %{
        "description" => "Test incident description",
        "sensitive" => ["Not Sensitive"],
        "more_info" => ["This More Info section is invalid because", "It's in an array"]
      })

    assert json_response(conn, 401) == %{"error" => %{"attr_more_info" => "is invalid"}}

    # TODO check URL validation fails loudly
    # TODO ensure arbitrary optional attribute values are stored correctly
     end
end
