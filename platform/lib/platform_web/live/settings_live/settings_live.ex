defmodule PlatformWeb.SettingsLive do
  use PlatformWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Settings")
     |> assign(:discord_link, System.get_env("COMMUNITY_DISCORD_LINK"))}
  end

  def handle_info(:update_successful, socket) do
    {:noreply, socket |> put_flash(:info, "Changes saved successfully")}
  end
end
