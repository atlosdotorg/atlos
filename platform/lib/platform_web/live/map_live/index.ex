defmodule PlatformWeb.MapLive.Index do
  use PlatformWeb, :live_view
  alias Platform.Material

  def mount(_params, _session, socket) do
    results =
      Material.list_geolocated_media()
      |> Enum.filter(&Material.Media.can_user_view(&1, socket.assigns.current_user))

    {:ok,
     socket
     |> assign(:title, "Map")
     |> assign(:media, results)
     |> assign(:changeset, Material.MediaSearch.changeset())}
  end
end
