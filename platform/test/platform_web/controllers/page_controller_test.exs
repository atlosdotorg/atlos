defmodule PlatformWeb.PageControllerTest do
  use PlatformWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 302) =~ "redirected"
  end
end
