defmodule PlatformWeb.WatchingLive do
  use PlatformWeb, :live_view
  alias Platform.Material

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:title, "Watching") |> assign(:media, list_media(socket))}
  end

  def list_media(socket) do
    Material.list_watched_media(socket.assigns.current_user)
  end
end
