defmodule PlatformWeb.PageController do
  use PlatformWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: "/map")
  end
end
