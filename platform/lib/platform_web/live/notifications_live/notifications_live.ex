defmodule PlatformWeb.NotificationsLive do
  use PlatformWeb, :live_view
  alias Platform.Material
  alias Platform.Updates

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Notifications")
     |> assign(:media, list_media(socket))
     |> perform_search()}
  end

  defp perform_search(socket, extend \\ [], opts \\ []) do
    result =
      Updates.query_updates_paginated(
        Updates.query_updates_for_user(socket.assigns.current_user, exclude_hidden: true),
        opts
      )

    socket |> assign(:result, result) |> assign(:updates, result.entries ++ extend)
  end

  def handle_event("load_more", _params, socket) do
    cursor_after = socket.assigns.result.metadata.after

    {:noreply, socket |> perform_search(socket.assigns.updates, after: cursor_after)}
  end

  def list_media(socket) do
    Material.list_subscribed_media(socket.assigns.current_user)
  end
end
