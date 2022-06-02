defmodule PlatformWeb.MediaLive.Index do
  use PlatformWeb, :live_view
  alias Platform.Material

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Incidents")
     |> assign(:changeset, Material.MediaSearch.changeset())
     |> assign(:query_params, %{})}
  end

  def handle_event("validate", params, socket) do
    handle_event("save", params, socket)
  end

  def handle_event("save", %{"search" => params}, socket) do
    c = Material.MediaSearch.changeset(params)

    if c.valid? do
      {:noreply,
       socket
       |> assign(:changeset, c)
       |> assign(:query_params, c.changes)}
    else
      {:noreply, socket |> assign(:changeset, c)}
    end
  end
end
