defmodule PlatformWeb.SettingsLive.EmailPreferencesComponent do
  use PlatformWeb, :live_component
  alias Platform.Accounts
  alias Platform.Uploads.Avatar
  alias Platform.Auditor

  def update(%{current_user: current_user} = assigns, socket) do
    changeset = Accounts.change_user_preferences(current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.current_user
      |> Accounts.change_user_preferences(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.update_user_preferences(socket.assigns.current_user, user_params) do
      {:ok, user} ->
        Auditor.log(:preferences_updated, user_params, socket)
        send(self(), :update_successful)

        {:noreply,
         socket
         |> assign(:current_user, user)
         |> assign(:changeset, Accounts.change_user_preferences(user))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def render(assigns) do
    ~H"""
    <article>
      <.form
        :let={f}
        for={@changeset}
        id="preferences-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="phx-form"
      >
        <div class="space-y-6">
          <div>
            <p class="text-sm font-medium text-neutral-500 mb-4">Send me an email when...</p>
            <div class="mt-1 flex flex-col">
              <%= label(f, :send_mention_notification_emails, class: "flex items-center") do %>
                <%= checkbox(f, :send_mention_notification_emails, class: "mr-2") %>
                <span class="!font-medium text-neutral-800 text-sm mt-px">
                  Someone mentions
                  <span data-tag-target={@current_user.username} class="p-1 rounded">
                    @<%= @current_user.username %>
                  </span>
                  in a comment
                </span>
              <% end %>
              <label class="flex items-center cursor-disabled">
                <input type="checkbox" name="on_login" class="mr-2 opacity-50" disabled checked />
                <span class="!font-medium text-neutral-800 text-sm mt-px">
                  Someone logs into my account
                  <span class="text-neutral-500">(required for all accounts)</span>
                </span>
              </label>
            </div>
          </div>

          <div class="flex flex-col items-center md:flex-row md:justify-between gap-2">
            <%= submit("Save",
              phx_disable_with: "Saving...",
              class: "button ~urge @high",
              disabled: @changeset.changes == %{}
            ) %>
          </div>
        </div>
      </.form>
    </article>
    """
  end
end
