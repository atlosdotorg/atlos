defmodule PlatformWeb.APIV1Test do
  use PlatformWeb.ConnCase
  import Platform.APIFixtures
  import Platform.MaterialFixtures
  alias Platform.Material

  test "GET /api/v1/media", %{conn: conn} do
    # TODO: add tests that also check pagination is working

    noauth_conn = get(conn, "/api/v1/media")
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    noauth_conn = get(put_req_header(conn, "authorization", "Bearer "), "/api/v1/media")
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    noauth_conn = get(put_req_header(conn, "authorization", "Bearer bad"), "/api/v1/media")
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    token = api_token_fixture()

    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> get("/api/v1/media")

    assert json_response(auth_conn, 200) == %{"results" => [], "previous" => nil, "next" => nil}

    media = media_fixture()

    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> get("/api/v1/media")

    assert json_response(auth_conn, 200) == %{
             # Manually fetch since the database will change certain values
             "results" => [
               Jason.decode!(
                 Jason.encode!(Material.get_media!(media.id) |> Map.put(:versions, []))
               )
             ],
             "previous" => nil,
             "next" => nil
           }
  end

  test "GET /api/v1/media with pagination" do
    n = 1501

    Enum.map(0..(n - 1), fn _ -> media_fixture() end)

    token = api_token_fixture()

    {media, final_next} =
      Enum.reduce(0..(ceil(n / 50) + 25), {[], :start}, fn _, {elems, next} ->
        if not is_nil(next) do
          auth_conn =
            build_conn()
            |> put_req_header("authorization", "Bearer " <> token.value)
            |> get(
              if next != :start,
                do: "/api/v1/media?cursor=#{next}",
                else: "/api/v1/media"
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

  test "GET /api/v1/media_versions", %{conn: conn} do
    # TODO: add tests that also check pagination is working

    noauth_conn = get(conn, "/api/v1/media_versions")
    assert json_response(noauth_conn, 401) == %{"error" => "invalid token or token not found"}

    token = api_token_fixture()

    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> get("/api/v1/media_versions")

    assert json_response(auth_conn, 200) == %{"results" => [], "previous" => nil, "next" => nil}

    media = media_fixture()
    media_version_fixture(%{media_id: media.id})

    auth_conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token.value)
      |> get("/api/v1/media_versions")

    assert json_response(auth_conn, 200) == %{
             "results" => Jason.decode!(Jason.encode!(Material.list_media_versions())),
             "previous" => nil,
             "next" => nil
           }
  end
end
