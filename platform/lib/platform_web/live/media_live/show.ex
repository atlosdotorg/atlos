defmodule PlatformWeb.MediaLive.Show do
  use PlatformWeb, :live_view
  alias Platform.Material
  alias Material.Attribute
  alias PlatformWeb.MediaLive.EditAttribute
  alias Material.Media

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"slug" => slug} = params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:slug, slug)
     |> assign(:attribute, Map.get(params, "attribute"))
     |> assign_media_and_updates()}
  end

  def filter_editable(attributes, media, user) do
    attributes
    |> Enum.filter(fn attr ->
      Attribute.can_user_edit(attr, user, media)
    end)
  end

  defp assign_media_and_updates(socket) do
    with %Material.Media{} = media <- Material.get_full_media_by_slug(socket.assigns.slug),
         true <- Media.can_user_view(media, socket.assigns.current_user) do
      socket |> assign(:media, media) |> assign(:updates, media.updates)
    else
      _ ->
        socket
        |> put_flash(:error, "This media does not exist or is not available.")
        |> redirect(to: "/")
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket |> push_patch(to: Routes.media_show_path(socket, :show, socket.assigns.media.slug))}
  end

  def handle_info({:version_created, _version}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "The media was uploaded successfully.")
     |> push_patch(to: Routes.media_show_path(socket, :show, socket.assigns.media.slug))}
  end
end
