defmodule PlatformWeb.MediaLive.Index do
  use PlatformWeb, :live_view
  alias Platform.Material
  alias Platform.Material.Attribute

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Incidents")}
  end

  def handle_params(params, _uri, socket) do
    display = Map.get(params, "display", "cards")

    {:noreply,
     socket
     |> assign(
       :changeset,
       Material.MediaSearch.changeset(params)
     )
     |> assign(:display, display)
     |> assign(:full_width, display == "table")
     |> assign(:query_params, params)}
  end

  def handle_event("validate", params, socket) do
    handle_event("save", params, socket)
  end

  def handle_event("save", %{"search" => params}, socket) do
    {:noreply, socket |> push_patch(to: Routes.live_path(socket, __MODULE__, params))}
  end
end
