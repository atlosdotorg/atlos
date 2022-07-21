defmodule PlatformWeb.APIV1Test do
  use PlatformWeb.ConnCase
  import Platform.APIFixtures
  import Platform.MaterialFixtures
  alias Platform.Material

  test "GET /api/v1/media", %{conn: conn} do
    noauth_conn = get(conn, "/api/v1/media")
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    token = api_token_fixture()

    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> get("/api/v1/media")

    assert json_response(auth_conn, 200) == %{"results" => []}

    media = media_fixture()

    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> get("/api/v1/media")

    assert json_response(auth_conn, 200) == %{
             # Manually fetch since the database will change certain values
             "results" => [Jason.decode!(Jason.encode!(Material.get_media!(media.id)))]
           }
  end

  test "GET /api/v1/media_versions", %{conn: conn} do
    noauth_conn = get(conn, "/api/v1/media_versions")
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    token = api_token_fixture()

    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> get("/api/v1/media_versions")

    assert json_response(auth_conn, 200) == %{"results" => []}

    media = media_fixture()
    version = media_version_fixture(%{media_id: media.id})

    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> get("/api/v1/media_versions")

    assert json_response(auth_conn, 200) == %{
             "results" => Jason.decode!(Jason.encode!(Material.list_media_versions()))
           }
  end
end
