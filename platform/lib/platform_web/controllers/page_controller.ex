defmodule PlatformWeb.PageController do
  use PlatformWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: "/home")
  end

  def new(conn, _params) do
    redirect(conn, to: "/home#new")
  end
end
