defmodule PlatformWeb.HomeLive.Index do
  use PlatformWeb, :live_view
  alias Platform.Material
  alias Platform.Permissions

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Home")}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:root_pid, self())
     |> assign(:pagination_index, 0)
     |> assign(:projects, Platform.Projects.list_projects_for_user(socket.assigns.current_user))
     |> assign(:media, get_feed_media(socket, limit: 50))
     |> assign(
       :status_statistics,
       Material.status_overview_statistics(for_user: socket.assigns.current_user)
     )
     |> assign(:additional_results_available, true)
     |> assign(:overview_media, get_overview_media(socket))
     |> assign(:full_width, true)
     |> assign(:search_changeset, Material.MediaSearch.changeset())}
  end

  defp get_feed_media(socket, opts) do
    Material.get_recently_updated_media_paginated(
      Keyword.merge(opts,
        for_user: socket.assigns.current_user
      )
    )
    |> Enum.filter(&Permissions.can_view_media?(socket.assigns.current_user, &1))
  end

  defp get_overview_media(socket, opts \\ []) do
    recently_modified_by_user =
      Material.get_recently_updated_media_paginated(
        Keyword.merge(opts,
          limit: 25,
          restrict_to_user: socket.assigns.current_user,
          for_user: socket.assigns.current_user
        )
      )

    recently_modified_with_notification =
      Material.get_recently_updated_media_paginated(
        Keyword.merge(opts,
          limit: 25,
          for_user: socket.assigns.current_user,
          limit_to_unread_notifications: true
        )
      )

    recently_modified_subscriptions =
      Material.get_recently_updated_media_paginated(
        Keyword.merge(opts,
          limit: 25,
          restrict_to_user: socket.assigns.current_user,
          for_user: socket.assigns.current_user,
          limit_to_subscriptions: true
        )
      )

    recently_modified_assigned =
      Material.get_recently_updated_media_paginated(
        Keyword.merge(opts,
          limit: 25,
          restrict_to_user: socket.assigns.current_user,
          for_user: socket.assigns.current_user,
          limit_to_assignments: true
        )
      )

    {unclaimed_query, unclaimed_query_opts} =
      Material.MediaSearch.search_query(
        Material.MediaSearch.changeset(%{"attr_status" => "Unclaimed"})
      )

    unclaimed_for_backfill =
      Material.query_media_paginated(unclaimed_query, unclaimed_query_opts).entries

    (recently_modified_by_user ++
       recently_modified_with_notification ++
       recently_modified_subscriptions ++ recently_modified_assigned)
    |> Enum.sort_by(& &1.last_update_time, {:desc, NaiveDateTime})
    |> Enum.uniq_by(& &1.id)
    |> Enum.concat(unclaimed_for_backfill)
    |> Enum.filter(&Permissions.can_view_media?(socket.assigns.current_user, &1))
    |> Enum.take(4)
  end

  def handle_event("validate", params, socket) do
    # For the search bar
    handle_event("save", params, socket)
  end

  def handle_event("save", %{"search" => params}, socket) do
    # For the search bar
    {:noreply,
     socket
     |> push_navigate(
       to:
         Routes.live_path(
           socket,
           PlatformWeb.MediaLive.Index,
           params
         )
     )}
  end

  def handle_event("load_more", _params, socket, depth \\ 10) do
    results =
      get_feed_media(socket, offset: 10 * (socket.assigns.pagination_index + 1), limit: 50)

    old_media = socket.assigns.media

    media =
      (socket.assigns.media ++ results)
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(& &1.last_update_time, {:desc, NaiveDateTime})

    new_socket =
      socket
      |> assign(:pagination_index, socket.assigns.pagination_index + 1)
      |> assign(
        :media,
        media
      )
      |> assign(
        :additional_results_available,
        not Enum.empty?(results) or socket.assigns.pagination_index > 10
      )

    # Automatically recurse up to 10 times to try to get more results
    if length(old_media) == length(media) do
      if depth > 0 do
        handle_event("load_more", %{}, new_socket, depth - 1)
      else
        {:noreply, new_socket}
      end
    else
      {:noreply, new_socket}
    end
  end
end
