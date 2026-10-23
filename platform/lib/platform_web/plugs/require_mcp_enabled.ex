defmodule PlatformWeb.Plugs.RequireMCPEnabled do
  @moduledoc """
  Responds with 404 Not Found, as if the route didn't exist, unless the MCP
  server is enabled with the `MCP_ENABLED` environment variable. Guards the
  MCP endpoint and everything OAuth-related that exists to serve it.
  """

  import Plug.Conn

  def init(options), do: options

  def call(conn, _opts) do
    if PlatformWeb.MCP.Server.enabled?() do
      conn
    else
      conn
      |> send_resp(:not_found, "Not Found")
      |> halt()
    end
  end
end
