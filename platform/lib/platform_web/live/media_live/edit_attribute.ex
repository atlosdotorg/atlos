defmodule PlatformWeb.MediaLive.EditAttribute do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Material.Media.Attribute

  def update(assigns, socket) do
    attr = Attribute.get_attribute(String.to_atom(assigns.name))
    {:ok, socket |> assign(assigns) |> assign(:attr, attr) |> assign(:changeset, Material.change_media_attribute(assigns.media, attr))}
  end

  def close(socket) do
    socket |> redirect(to: Routes.media_show_path(socket, :show, socket.assigns.media.slug))
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, close(socket)}
  end

  def handle_event("save", input, socket) do
    params = Map.get(input, "media", %{socket.assigns.attr.schema_field => nil}) # To allow empty strings, lists, etc.
    # TODO: find some way to differentiate between unset and empty

    case Material.update_media_attribute(socket.assigns.media, socket.assigns.attr, params) do
      {:ok, media} ->
        {:noreply, socket |> put_flash(:info, "Your update has been saved.") |> close()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("validate", input, socket) do
    params = Map.get(input, "media", %{socket.assigns.attr.schema_field => nil}) # To allow empty strings, lists, etc.

    changeset =
      socket.assigns.media
      |> Material.change_media_attribute(socket.assigns.attr, params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def render(assigns) do
    ~H"""
    <article>
      <.modal target={@myself}>
        <h3 class="sec-head"><%= @media.slug %>: <%= @attr.label %></h3>
        <p class="sec-subhead">Additional language about the attribute will be provided here, if necessary (TODO).</p>
        <hr class="h-8 sep">
        <.form
          let={f}
          for={@changeset}
          id={"#{@attr.schema_field}-attribute-form"}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
          class="phx-form"
        >
          <div class="space-y-6">
            <div>
              <%= label f, @attr.schema_field, @attr.label %>
              <%= case @attr.type do %>
                <% :text -> %>
                  <%= textarea f, @attr.schema_field, phx_debounce: "blur" %>
                <% :multi_select -> %>
                  <div phx-update="ignore">
                    <%= multiple_select f, @attr.schema_field, @attr.options, phx_debounce: "blur" %>
                  </div>
              <% end %>
              <%= error_tag f, @attr.schema_field %>
            </div>
            <div>
              <%= submit "Post update →", phx_disable_with: "Saving...", class: "button ~urge @high" %>
            </div>
          </div>
        </.form>
      </.modal>
    </article>
    """
  end
end
