defmodule PlatformWeb.NewLive.BasicInfoLive do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Material.Attribute

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_media()
     |> assign_changeset()
     |> assign(:disabled, false)}
  end

  defp assign_media(socket) do
    socket |> assign(:media, %Material.Media{})
  end

  defp assign_changeset(socket) do
    socket |> assign(:changeset, Material.change_media(socket.assigns.media))
  end

  def handle_event("validate", %{"media" => media_params}, socket) do
    changeset =
      socket.assigns.media |> Material.change_media(media_params) |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"media" => media_params}, socket) do
    case Material.create_media_audited(socket.assigns.current_user, media_params) do
      {:ok, media} ->
        {:ok, _} = Material.subscribe_user(media, socket.assigns.current_user)
        send(self(), {:media_created, media})
        {:noreply, socket |> assign(:disabled, true)}

      {:error, %Ecto.Changeset{} = changeset} ->
        IO.inspect(changeset)
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <.form
        let={f}
        for={@changeset}
        id="media-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="phx-form"
      >
        <div class="space-y-6">
          <div>
            <%= label f, :description, "Short Description" %>
            <%= textarea f, :description, class: "text-xl", rows: 2, disabled: @disabled, phx_debounce: "blur" %>
            <p class="support">Try to be as descriptive as possible. You'll be able to change this later.</p>
            <%= error_tag f, :description %>
          </div>

          <div>
            <%= label f, :attr_sensitive, "Media Sensitivity (select all that apply)" %>
            <div phx-update="ignore" id="sensitive_select">
              <%= multiple_select f, :attr_sensitive, Attribute.get_attribute(:sensitive) |> Attribute.options() %>
            </div>
            <p class="support">Is this media sensitive? This information helps us keep our community safe.</p>
            <%= error_tag f, :attr_sensitive %>
          </div>

          <div class="rounded-md bg-neutral-100 p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <!-- Heroicon name: solid/information-circle -->
                <svg class="h-5 w-5 text-neutral-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <p class="text-sm text-neutral-700">Some kind of language telling people about Atlos policies. Lorem ipsum dolor sit amet.</p>
                <div class="mt-2 text-sm text-neutral-700">
                  <ul role="list" class="list-disc pl-5 space-y-1">
                    <li>Policy language</li>
                    <li>Even more policy language</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>

          <%= submit "Upload media →", phx_disable_with: "Saving...", class: "button ~urge @high", disabled: @disabled %>
        </div>
      </.form>
    </div>
    """
  end
end
