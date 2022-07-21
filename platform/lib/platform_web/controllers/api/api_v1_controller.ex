defmodule PlatformWeb.APIV1Controller do
  use PlatformWeb, :controller

  alias Platform.Material

  def media_versions(conn, _params) do
    json(conn, %{results: Material.list_media_versions()})
  end

  def media(conn, _params) do
    json(conn, %{results: Material.list_media()})
  end
end
