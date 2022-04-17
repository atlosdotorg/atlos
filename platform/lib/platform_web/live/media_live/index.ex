defmodule PlatformWeb.MediaLive.Index do
  use PlatformWeb, :live_view
  alias Platform.Material

  def mount(_params, _session, socket) do
    results = search_media(socket, Material.MediaSearch.changeset())

    {:ok,
     socket
     |> assign(:title, "Media")
     |> assign(:results, results)
     |> assign(:media, results.entries)
     |> assign(:changeset, Material.MediaSearch.changeset())}
  end

  def handle_event("validate", %{"search" => params}, socket) do
    c =
      Material.MediaSearch.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, c)}
  end

  def handle_event("save", %{"search" => params}, socket) do
    c = Material.MediaSearch.changeset(params)

    if c.valid? do
      results = search_media(socket, c)
      {:noreply,
       socket
       |> assign(:changeset, c)
       |> assign(:results, results)
       |> assign(:media, results.entries)}
    else
      {:noreply, socket |> assign(:changeset, c)}
    end
  end

  def handle_event("load_more", _params, socket) do
    cursor_after = socket.assigns.results.metadata.after
    results = search_media(socket, socket.assigns.changeset, after: cursor_after)

    new_socket = socket
      |> assign(:results, results)
      |> assign(:media, socket.assigns.media ++ results.entries)

    {:noreply, new_socket}
  end

  defp search_media(socket, c, pagination_opts \\ []) do
    Material.MediaSearch.search_query(c)
    |> Material.MediaSearch.filter_viewable(socket.assigns.current_user)
    |> Material.query_media_paginated(pagination_opts)
  end
end
