defmodule PlatformWeb.NotificationsLive do
  use PlatformWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Notifications")}
  end
end
