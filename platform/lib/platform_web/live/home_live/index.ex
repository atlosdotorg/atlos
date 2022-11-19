defmodule PlatformWeb.HomeLive.Index do
  use PlatformWeb, :live_view
  alias Platform.Material
  alias Platform.Accounts

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Home")}
  end

  def handle_params(_params, _uri, socket) do
    results = get_feed_media(socket)

    {:noreply,
     socket
     |> assign(:myself, self())
     |> assign(:pagination_index, 0)
     |> assign(:media, results.entries)
     |> assign(:overview_media, get_overview_media(socket).entries)
     |> assign(:results, results)
     |> assign(:full_width, true)}
  end

  defp get_feed_media(socket, opts \\ []) do
    Material.get_recently_updated_media_paginated(
      Keyword.merge(opts,
        limit: 10,
        for_user: socket.assigns.current_user
      )
    )
  end

  defp get_overview_media(socket, opts \\ []) do
    Material.get_recently_updated_media_paginated(
      Keyword.merge(opts,
        limit: 4,
        restrict_to_user: socket.assigns.current_user,
        for_user: socket.assigns.current_user
      )
    )
  end

  def handle_event("load_more", _params, socket) do
    cursor_after = socket.assigns.results.metadata.after

    results = get_feed_media(socket, after: cursor_after)

    new_socket =
      socket
      |> assign(:results, results)
      |> assign(:pagination_index, socket.assigns.pagination_index + 1)
      |> assign(:media, socket.assigns.media ++ results.entries)

    {:noreply, new_socket}
  end
end
