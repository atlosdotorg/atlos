defmodule PlatformWeb.MediaLive.Index do
  use PlatformWeb, :live_view
  alias Platform.Material

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:title, "Media") |> assign(:media, list_media(socket))}
  end

  def list_media(_socket) do
    Material.list_media()
  end
end
