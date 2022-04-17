defmodule PlatformWeb.MediaLive.Index do
  use PlatformWeb, :live_view
  alias Platform.Material

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Media")
     |> assign(:media, search_media(socket, Material.MediaSearch.changeset()))
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
      {:noreply,
       socket
       |> assign(:changeset, c)
       |> assign(:media, search_media(socket, c))}
    else
      {:noreply, socket |> assign(:changeset, c)}
    end
  end

  defp search_media(socket, c) do
    Material.MediaSearch.search_query(c)
    |> Material.MediaSearch.filter_viewable(socket.assigns.current_user)
    |> Material.query_media()
  end
end
