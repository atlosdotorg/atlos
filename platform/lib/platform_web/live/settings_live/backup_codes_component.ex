defmodule PlatformWeb.SettingsLive.BackupComponent do
  use PlatformWeb, :live_component
  alias Platform.Accounts
  alias Platform.Utils

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)}
  end

  def handle_event("generate_recovery_codes", _v, socket) do
    case Accounts.update_user_recovery_code(
           socket.assigns.current_user,
           %{:recovery_codes => Utils.generate_recovery_codes(), :used_recovery_codes => []}
         ) do
      {:ok, user} ->
        Platform.Auditor.log(:recovery_codes_generated, %{email: user.email}, socket)

        {:noreply,
         socket
         |> assign(:current_user, user)}

      {:error, changeset} ->
        {:noreply, socket |> assign(:disable_changeset, changeset)}
    end
  end

  def handle_event("delete_recovery_codes", _v, socket) do
    case Accounts.update_user_recovery_code(
           socket.assigns.current_user,
           %{:recovery_codes => [], :used_recovery_codes => []}
         ) do
      {:ok, user} ->
        Platform.Auditor.log(:recovery_codes_deleted, %{email: user.email}, socket)

        {:noreply,
         socket
         |> assign(:current_user, user)}

      {:error, changeset} ->
        {:noreply, socket |> assign(:disable_changeset, changeset)}
    end
  end

  def render(assigns) do
    token =
      Phoenix.Token.sign(PlatformWeb.Endpoint, "backup_codes_export", %{
        :uid => assigns.current_user.id
      })

    assigns = Map.put(assigns, :token, token)

    ~H"""
    <div>
      <.card>
        <:header>
          <h3 class="sec-head">Backup Codes</h3>
          <p class="sec-subhead">
            Generate backup codes to use in case you lose access to your authenticator app.
          </p>
        </:header>
        <p class="-mt-1">
          <%= if not (Enum.empty?(@current_user.recovery_codes) and Enum.empty?(@current_user.used_recovery_codes)) do %>
            <%= for code <- @current_user.recovery_codes do %>
              <span class="font-mono bg-gray-100 px-2 py-1 rounded mr-2 mt-2 inline-block">
                <%= Platform.Utils.format_recovery_code(code) %>
              </span>
            <% end %>
            <%= for code <- @current_user.used_recovery_codes do %>
              <span class="font-mono bg-gray-100 px-2 py-1 rounded mr-2 mt-2 inline-block line-through">
                <%= Platform.Utils.format_recovery_code(code) %>
              </span>
            <% end %>
            <div>
              <%= button type: "button", to: Routes.export_path(@socket, :create_backup_codes_export, %{
                :token => @token
              }),
                    class: "button ~urge @high",
                    method: :post,
                    target: "_blank"
                do %>
                <div>
                  <Heroicons.arrow_down_tray mini class="w-4 h-4 mr-1 inline-block" /> Download
                </div>
              <% end %>
              <button
                phx-click="generate_recovery_codes"
                phx-target={@myself}
                data-confirm="Please confirm that you want to generate a new set of backup codes. Your old codes will no longer work after this action."
                class="button ~urge @high mt-4"
              >
                <span class="phx-only-during-reg">
                  <Heroicons.arrow_path mini class="w-4 h-4 mr-1 inline-block" /> Regenerate Codes
                </span>
                <span class="phx-only-during-submit">
                  <.loading_spinner text="Generating..." />
                </span>
              </button>
              <button
                phx-click="delete_recovery_codes"
                data-confirm="Please confirm that you want to remove all backup codes. You won't be able to use those backup codes again."
                phx-target={@myself}
                class="button ~critical @high mt-4"
              >
                <span class="phx-only-during-reg">
                  <Heroicons.trash mini class="w-4 h-4 mr-1 inline-block" /> Delete All Codes
                </span>
                <span class="phx-only-during-submit">
                  <.loading_spinner text="Deleting..." />
                </span>
              </button>
            </div>
          <% else %>
            <p class="support">
              You currently don't have any backup codes setup. Backup codes can be used to log into Atlos if you lose access to your authenticator app.
            </p>
            <button
              phx-click="generate_recovery_codes"
              phx-disable-with="Generating codes..."
              phx-target={@myself}
              class="button ~urge @high mt-4"
            >
              Get Backup Codes
            </button>
          <% end %>
        </p>
      </.card>
    </div>
    """
  end
end
