defmodule PlatformWeb.NotificationsLive do
  use PlatformWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Notifications")}
  end

  def handle_params(unsigned_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:params, %{
       "filter" => Map.get(unsigned_params, "filter", "all"),
       "sort" => Map.get(unsigned_params, "sort", "newest"),
       "query" => Map.get(unsigned_params, "query", "")
     })}
  end

  def handle_event("update_filters", params, socket) do
    {:noreply,
     socket
     |> push_patch(to: Routes.live_path(socket, PlatformWeb.NotificationsLive, params))}
  end
end
