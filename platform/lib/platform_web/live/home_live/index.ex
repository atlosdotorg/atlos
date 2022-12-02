defmodule PlatformWeb.HomeLive.Index do
  use PlatformWeb, :live_view
  alias Platform.Material

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Home")}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:myself, self())
     |> assign(:pagination_index, 0)
     |> assign(:status_statistics, Material.status_overview_statistics())
     |> assign(:media, get_feed_media(socket, limit: 50))
     |> assign(:additional_results_available, true)
     |> assign(:overview_media, get_overview_media(socket))
     |> assign(:full_width, true)
     |> assign(:search_changeset, Material.MediaSearch.changeset())}
  end

  defp get_feed_media(socket, opts \\ []) do
    Material.get_recently_updated_media_paginated(
      Keyword.merge(opts,
        for_user: socket.assigns.current_user,
        restrict_to_user:
          if(socket.assigns.live_action == :my_activity,
            do: socket.assigns.current_user,
            else: nil
          )
      )
    )
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

    (recently_modified_by_user ++
       recently_modified_with_notification ++ recently_modified_subscriptions)
    |> Enum.sort_by(& &1.last_update_time, {:desc, NaiveDateTime})
    |> Enum.uniq_by(& &1.id)
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
     |> redirect(
       to:
         Routes.live_path(
           socket,
           PlatformWeb.MediaLive.Index,
           params |> Map.put("display", "cards")
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
