defmodule PlatformWeb.SettingsLive do
  use PlatformWeb, :live_view

  def mount(params, _session, socket) do
    # If billing is enabled and we have a user, we need to check if the user has a billing_customer_id
    billing_session_client_secret =
      if Platform.Billing.is_enabled?() do
        {:ok, secret} =
          Platform.Billing.get_customer_session_client_secret(socket.assigns.current_user)

        secret
      else
        nil
      end

    {:ok,
     socket
     # We reassign the user because we need to get the latest billing information
     |> assign(:billing_session_client_secret, billing_session_client_secret)
     |> assign(
       :user_rolling_update_count,
       Platform.Updates.get_total_updates_by_user_over_30d(socket.assigns.current_user)
     )
     |> assign(:title, "Settings")
     |> assign(:discord_link, System.get_env("COMMUNITY_DISCORD_LINK"))}
  end

  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:show_billing_confirmation, Map.get(params, "checkout_success") == "true")}
  end

  def handle_event("visit_customer_portal", _params, socket) do
    case Platform.Billing.get_portal_url(socket.assigns.current_user) do
      {:ok, url} -> {:noreply, socket |> redirect(external: url)}
      {:error, _} -> {:noreply, socket |> put_flash(:error, "Failed to get customer portal URL")}
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> push_patch(to: "/settings")}
  end

  def handle_info(:update_successful, socket) do
    {:noreply, socket |> put_flash(:info, "Changes saved successfully")}
  end
end
