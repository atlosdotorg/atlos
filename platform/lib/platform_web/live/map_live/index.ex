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
     |> assign_map_data()}
  end

  def assign_map_data(%{assigns: %{media: media}} = socket) do
    data =
      Enum.map(media, fn item ->
        {lon, lat} = item.attr_geolocation.coordinates

        %{
          slug: item.slug,
          # Stringify to avoid floating point issues
          lat: "#{lat}",
          lon: "#{lon}"
        }
      end)

    socket
    |> assign(:map_data, data)
  end
end
