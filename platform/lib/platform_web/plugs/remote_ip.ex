defmodule PlatformWeb.Plugs.RemoteIp do
  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    remote_ip = case :inet_parse.ntoa(conn.remote_ip) do
      {:error, _} -> "localhost"
      ip -> to_string(ip)
    end

    Logger.metadata(remote_ip: remote_ip)

    conn
    |> fetch_session()
    # We put the remote in three places, just to make sure it's always accessible.
    # MountHelperLive will also assign this value to sockets on mount.
    |> Map.put(:remote_ip, remote_ip)
    |> put_session(:remote_ip, remote_ip)
    |> assign(:remote_ip, remote_ip)
  end
end
