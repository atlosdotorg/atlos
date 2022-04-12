defmodule PlatformWeb.MediaLive.Show do
  use PlatformWeb, :live_view
  alias Platform.Material
  alias Material.Attribute
  alias PlatformWeb.MediaLive.EditAttribute
  alias Material.Media
  alias Platform.Accounts
  alias Accounts.User

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

  defp filter_editable(attributes, media, %User{} = user) do
    attributes
    |> Enum.filter(fn attr ->
      Attribute.can_user_edit(attr, user, media)
    end)
  end

  defp filter_viewable_versions(versions, %User{} = user) do
    versions |> Enum.filter(&Material.MediaVersion.can_user_view(&1, user))
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

  def handle_event("toggle_media_visibility", %{"version" => version} = _params, socket) do
    # NB: This is the only place we check permission to perform the action, since
    # changing media visibility is not an action that generates an update.
    if Accounts.is_privileged(socket.assigns.current_user) do
      version = Material.get_media_version!(version)
      {:ok, _} = Material.update_media_version(version, %{hidden: !version.hidden})

      {:noreply,
       socket
       |> assign_media_and_updates()
       |> put_flash(:info, "Media visibility changed successfully.")}
    else
      {:noreply,
       socket |> put_flash(:error, "You do not have permission to change media visibility.")}
    end
  end

  def handle_info({:version_created, _version}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "The media was uploaded successfully.")
     |> push_patch(to: Routes.media_show_path(socket, :show, socket.assigns.media.slug))}
  end
end
