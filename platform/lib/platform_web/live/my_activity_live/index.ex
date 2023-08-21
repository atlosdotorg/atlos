defmodule PlatformWeb.MyActivityLive.Index do
  use PlatformWeb, :live_view
  alias Platform.Material
  alias Platform.Permissions

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "My Activity")}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:root_pid, self())
     |> assign(:full_width, false)
     |> assign(:pagination_index, 0)
     |> assign(:additional_results_available, true)}
  end

  defp get_feed_media(socket, opts) do
    Material.get_recently_updated_media_paginated(
      Keyword.merge(opts,
        for_user: socket.assigns.current_user,
        restrict_to_user: socket.assigns.current_user
      )
    )
    |> Enum.filter(&Permissions.can_view_media?(socket.assigns.current_user, &1))
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
