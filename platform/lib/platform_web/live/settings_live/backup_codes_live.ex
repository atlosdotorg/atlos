defmodule PlatformWeb.SettingsLive.BackupCodesLive do
  use PlatformWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Set Up Backup Codes")
    }
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-xl md:mx-auto mx-4">
      <h1 class="page-header">Set Up Backup Codes</h1>
      <.mfa_status user={@current_user} />
      <%= if @current_user.has_mfa do %>
        <.live_component
          module={PlatformWeb.SettingsLive.BackupComponent}
          id="backup-codes-component"
          current_user={@current_user}
        />
      <% end %>
      <.link navigate="/settings/mfa" class="text-button mt-4 block">&larr; Multifactor Auth</.link>
    </div>
    """
  end
end
