defmodule PlatformWeb.MediaLive.Show do
  use PlatformWeb, :live_view
  alias Platform.Material
  alias Material.Attribute
  alias Platform.Updates

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"slug" => slug} = params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:slug, slug)
     |> assign(:attribute, Map.get(params, "attribute"))
     |> assign_media()
     |> assign_updates()
    }
  end

  defp assign_media(socket) do
    with %Material.Media{} = media <- Material.get_full_media_by_slug(socket.assigns.slug) do
      socket |> assign(:media, media)
    else
      nil ->
        socket
        |> put_flash(:error, "This media does not exist or is not publicly visible.")
        |> redirect(to: "/")
    end
  end

  def assign_updates(socket) do
    socket
    |> assign(:updates, Updates.get_updates_for_media(socket.assigns.media))
  end
end
