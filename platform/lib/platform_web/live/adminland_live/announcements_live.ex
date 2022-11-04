defmodule PlatformWeb.AdminlandLive.AnnouncementsLive do
  use PlatformWeb, :live_component
  use Ecto.Schema

  alias Platform.Notifications

  def mount(socket) do
    {:ok, socket, temporary_assigns: [message: nil]}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:changeset, fn -> changeset() end)}
  end

  defp changeset(params \\ %{}) do
    {params, %{message: :string}}
    |> Ecto.Changeset.cast(params, [:message])
    |> Ecto.Changeset.validate_required([:message])
    |> Ecto.Changeset.validate_length(:message, max: 3000, min: 5)
  end

  def handle_event("validate", %{"announcement" => params}, socket) do
    {:noreply, socket |> assign(:changeset, changeset(params) |> Map.put(:action, "validate"))}
  end

  def handle_event("save", %{"announcement" => params}, socket) do
    cs = changeset(params)

    if cs.valid? do
      message = Ecto.Changeset.get_field(cs, :message)
      Notifications.send_message_notification(message)

      # Create announcement
      {:noreply,
       socket
       |> assign(:changeset, changeset())
       |> assign(
         :message,
         "Your announcement was posted successfully. All users (including you) will receive a notification shortly."
       )}
    else
      handle_event("validate", %{"announcement" => params}, socket)
    end
  end

  def render(assigns) do
    ~H"""
    <section class="max-w-3xl mx-auto">
      <div>
        <.card>
          <:header>
            <div class="flex flex-col md:flex-row gap-4 md:gap-8 justify-between">
              <div>
                <p class="sec-head">Announcements</p>
                <p class="sec-subhead">Send an announcement to everyone on Atlos.</p>
              </div>
            </div>
          </:header>
          <%= if not is_nil(@message) do %>
            <aside class="aside ~urge mb-4">
              <%= @message %>
            </aside>
          <% end %>
          <.form
            :let={f}
            for={@changeset}
            as={:announcement}
            phx-change="validate"
            phx-submit="save"
            phx-target={@myself}
            class="phx-form"
          >
            <div class="gap-2">
              <%= label(f, :message, "Message", class: "block text-sm font-medium text-gray-700") %>
              <div class="mt-1">
                <%= textarea(f, :message,
                  placeholder: "Enter a message (markdown is allowed).",
                  phx_debounce: "500",
                  rows: 4,
                  class:
                    "block w-full rounded-md border-gray-300 shadow-sm focus:border-urge-500 focus:ring-urge-500 sm:text-sm"
                ) %>
              </div>
              <%= error_tag(f, :message) %>
            </div>
            <%= submit("Post Announcement",
              class: "button ~urge @high mt-4",
              phx_disable_with: "Posting..."
            ) %>
          </.form>
        </.card>
      </div>
    </section>
    """
  end
end
