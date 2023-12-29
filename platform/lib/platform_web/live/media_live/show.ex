defmodule PlatformWeb.MediaLive.Show do
  use PlatformWeb, :live_view

  alias Phoenix.PubSub

  alias Platform.Material
  alias Material.Attribute
  alias PlatformWeb.MediaLive.EditAttribute
  alias Material.Media
  alias Platform.Accounts
  alias Accounts.User
  alias Platform.Notifications
  alias Platform.Permissions

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"slug" => slug} = params, _uri, socket) do
    found_slug = Material.find_raw_slug(slug)

    if found_slug != slug do
      {:noreply,
       socket
       |> redirect(to: "/incidents/#{found_slug}")}
    else
      {:noreply,
       socket
       |> assign(:full_width, true)
       |> assign(:slug, slug)
       |> assign(:attribute, Map.get(params, "attribute"))
       # For /detail
       |> assign(:scoped_id, Map.get(params, "scoped_id"))
       # Will also assign title
       |> assign_media_and_updates()}
    end
  end

  defp filter_editable(attributes, media, %User{} = user) do
    attributes
    |> Enum.filter(fn attr ->
      Permissions.can_edit_media?(user, media, attr)
    end)
  end

  defp sort_by_date(items) do
    items |> Enum.sort_by(& &1.updated_at, {:desc, NaiveDateTime})
  end

  defp filter_viewable_versions(versions, %User{} = user) do
    versions |> Enum.filter(&Permissions.can_view_media_version?(user, &1))
  end

  defp subscribe_to_media(socket, media) do
    if Map.get(socket.assigns, :pubsub_subscribed, false) do
      socket
    else
      PubSub.subscribe(Platform.PubSub, Material.pubsub_topic_for_media(media.id))
      socket |> assign(:pubsub_subscribed, true)
    end
  end

  defp assign_media_and_updates(socket) do
    with %Material.Media{} = media <- Material.get_full_media_by_slug(socket.assigns.slug),
         true <- Permissions.can_view_media?(socket.assigns.current_user, media) do
      # Mark notifications for this media as read
      Notifications.mark_notifications_as_read(socket.assigns.current_user, media)

      socket
      |> assign(:media, media)
      |> assign(
        :media_versions,
        media.versions |> filter_viewable_versions(socket.assigns.current_user) |> sort_by_date()
      )
      |> assign(:active_project, media.project)
      |> assign(:updates, media.updates |> Enum.sort_by(& &1.inserted_at, {:asc, NaiveDateTime}))
      |> subscribe_to_media(media)
      |> assign(:title, "#{media.slug}: #{media.attr_description |> Platform.Utils.truncate()}")
    else
      _ ->
        raise PlatformWeb.Errors.NotFound, "Media not found"
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> push_patch(
       to: Routes.media_show_path(socket, :show, socket.assigns.media.slug),
       replace: true
     )}
  end

  def handle_event(
        "set_media_visibility",
        %{"version" => version, "state" => value} = _params,
        socket
      ) do
    version = Material.get_media_version!(version)

    if (!Permissions.can_change_media_version_visibility?(
          socket.assigns.current_user,
          version
        ) && version.visibility == :removed) or
         !Permissions.can_edit_media?(socket.assigns.current_user, socket.assigns.media) do
      {:noreply,
       socket |> put_flash(:error, "You cannot change this media version's visibility.")}
    else
      {:ok, _} =
        case value do
          "visible" ->
            Material.update_media_version(version, %{visibility: value})

          "hidden" ->
            Material.update_media_version(version, %{visibility: value})

          "removed" ->
            if Permissions.can_change_media_version_visibility?(
                 socket.assigns.current_user,
                 version
               ) do
              Material.update_media_version(version, %{visibility: value})
            else
              raise PlatformWeb.Errors.Unauthorized, "No permission"
            end
        end

      {:noreply,
       socket
       |> assign_media_and_updates()
       |> put_flash(:info, "Media visibility changed successfully.")}
    end
  end

  def handle_event(
        "toggle_deleted",
        _params,
        socket
      ) do
    media = socket.assigns.media

    if Permissions.can_delete_media?(socket.assigns.current_user, media) do
      {:ok, media} =
        if media.deleted do
          Material.soft_undelete_media_audited(media, socket.assigns.current_user)
        else
          Material.soft_delete_media_audited(media, socket.assigns.current_user)
        end

      {:noreply,
       socket
       |> assign_media_and_updates()
       |> put_flash(:info, if(media.deleted, do: "Incident deleted.", else: "Incident restored."))
       |> assign(:media, media)}
    else
      {:noreply,
       socket |> put_flash(:error, "You cannot change this incident's deletion status.")}
    end
  end

  def handle_event(
        "rearchive_media_version",
        %{"version" => version} = _params,
        socket
      ) do
    version = Material.get_media_version!(version)

    if Permissions.can_rearchive_media_version?(
         socket.assigns.current_user,
         version
       ) do
      %Oban.Job{} = Material.rearchive_media_version(version)

      {:noreply,
       socket
       |> assign_media_and_updates()
       |> put_flash(:info, "Atlos will rearchive the source material.")}
    else
      {:noreply, socket |> put_flash(:error, "You cannot rearchive this source material.")}
    end
  end

  def handle_info({:version_add_complete, version}, socket) do
    {:noreply,
     socket
     |> then(fn x ->
       if is_nil(version),
         do: x,
         else:
           put_flash(
             x,
             :info,
             "Atlos will archive and process the media in the background. Check back in a few minutes."
           )
     end)
     |> push_patch(
       to: Routes.media_show_path(socket, :show, socket.assigns.media.slug),
       replace: true
     )}
  end

  def handle_info({:project_change_complete, media}, socket) do
    {:noreply,
     socket
     |> then(fn x ->
       if is_nil(media),
         do: x,
         else:
           put_flash(
             x,
             :info,
             "Project changed successfully."
           )
     end)
     |> push_patch(
       to: Routes.media_show_path(socket, :show, socket.assigns.media.slug),
       replace: true
     )}
  end

  def handle_info({:merge_completed, _version}, socket) do
    {:noreply,
     socket
     |> put_flash(
       :info,
       "Merge initiated! The media will continue to merge in the background."
     )
     |> push_patch(
       to: Routes.media_show_path(socket, :show, socket.assigns.media.slug),
       replace: true
     )}
  end

  def handle_info({:copy_completed, new_media}, socket) do
    {:noreply,
     socket
     |> put_flash(
       :info,
       "Copy complete. The new incident is [#{new_media.slug}](/incidents/#{new_media.slug})."
     )
     |> push_patch(
       to: Routes.media_show_path(socket, :show, socket.assigns.media.slug),
       replace: true
     )}
  end

  def handle_info({:version_creation_failed, _changeset}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Unable to process the given media. Please try again.")
     |> push_patch(
       to: Routes.media_show_path(socket, :show, socket.assigns.media.slug),
       replace: true
     )}
  end

  def handle_info({:media_updated}, socket) do
    {:noreply,
     socket
     |> assign_media_and_updates()}
  end
end
