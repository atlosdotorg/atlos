defmodule PlatformWeb.SettingsLive do
  use PlatformWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:title, "Settings")}
  end

  def handle_info(:update_successful, socket) do
    {:noreply, socket |> put_flash(:info, "Changes saved successfully")}
  end
end
