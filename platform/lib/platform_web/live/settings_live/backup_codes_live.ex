defmodule PlatformWeb.SettingsLive.BackupCodesLive do
  alias Platform.Accounts
  use PlatformWeb, :live_view

  require Logger

  def mount(query, _session, socket) do
    cs = Accounts.confirm_user_mfa(socket.assigns.current_user, query)

    if cs.valid? do
      {:ok,
       socket
       |> assign(:title, "Set Up Backup Codes")
       |> assign(:valid, true)}
    else
      # This should normally be unreachable
      {:ok,
       socket
       |> assign(:valid, false)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-xl md:mx-auto mx-4">
      <h1 class="page-header">Set Up Backup Codes</h1>
      <.mfa_status user={@current_user} />
      <%= if @current_user.has_mfa && @valid do %>
        <.live_component
          module={PlatformWeb.SettingsLive.BackupComponent}
          id="backup-codes-component"
          current_user={@current_user}
        />
      <% end %>
      <%= if @current_user.has_mfa && !@valid do %>
        <p class="text-red-600">Invalid backup code.</p>
      <% end %>
      <.link navigate="/settings/mfa" class="text-button mt-4 block">&larr; Multifactor Auth</.link>
    </div>
    """
  end
end
