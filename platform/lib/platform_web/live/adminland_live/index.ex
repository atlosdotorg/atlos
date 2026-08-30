defmodule PlatformWeb.AdminlandLive.Index do
  use PlatformWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:title, "Adminland")}
  end

  def handle_params(params, _uri, socket) do
    # We pass the full socket to children for audit logging
    {:noreply, socket |> assign(:full_socket, socket) |> assign(:params, params)}
  end
end
