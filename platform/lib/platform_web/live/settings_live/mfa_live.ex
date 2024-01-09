defmodule PlatformWeb.SettingsLive.MFALive do
  use PlatformWeb, :live_view
  alias Platform.Accounts
  alias Platform.Utils

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Multi-Factor Authentication")
     |> assign(:secret, nil)
     |> assign(:otp_passed, false)
     |> assign(:otp_gate, Accounts.confirm_user_mfa_changeset(socket.assigns.current_user))
     |> assign(:enable_changeset, Accounts.change_user_mfa_enabled(socket.assigns.current_user))
     |> assign(:disable_changeset, Accounts.change_user_mfa_disabled(socket.assigns.current_user))}
  end

  defp assign_new_secret(socket) do
    socket
    |> assign(:secret, generate_secret())
  end

  defp generate_secret() do
    NimbleTOTP.secret()
  end

  def handle_event("generate_code", _values, socket) do
    {:noreply, socket |> assign_new_secret()}
  end

  def handle_event("save_enable_mfa", %{"enable_mfa" => query}, socket) do
    case Accounts.update_user_mfa_enabled(
           socket.assigns.current_user,
           query
           |> Map.put("otp_secret", socket.assigns.secret)
         ) do
      {:ok, user} ->
        {:noreply,
         socket
         |> redirect(to: Routes.settings_backup_codes_path(socket, :backupcode, query))}

      {:error, changeset} ->
        {:noreply, socket |> assign(:enable_changeset, changeset)}
    end
  end

  def handle_event("save_disable_mfa", %{"disable_mfa" => query}, socket) do
    case Accounts.update_user_mfa_disabled(
           socket.assigns.current_user,
           query
         ) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_user, user)
         |> put_flash(:info, "MFA was disabled successfully.")}

      {:error, changeset} ->
        {:noreply, socket |> assign(:disable_changeset, changeset)}
    end
  end

  def handle_event("access_otp", %{"access_otp" => query}, socket) do
    changeset = Accounts.confirm_user_mfa(socket.assigns.current_user, query)

    if changeset.valid? do
      {:noreply,
       socket
       |> assign(:otp_passed, true)
       |> assign(:current_user, Ecto.Changeset.apply_changes(changeset))}
    else
      {:error, changeset} = changeset |> Ecto.Changeset.apply_action(:validate)

      {:noreply,
       socket
       |> assign(:otp_gate, changeset)}
    end
  end

  defp secret_url(user, secret) do
    NimbleTOTP.otpauth_uri(
      "Atlos:" <> user.username,
      secret,
      issuer: "Atlos"
    )
  end

  defp secret_qr_code(user, secret) do
    Utils.generate_qrcode(secret_url(user, secret))
  end
end
