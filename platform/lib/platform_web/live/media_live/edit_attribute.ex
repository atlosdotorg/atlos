defmodule PlatformWeb.MediaLive.EditAttribute do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Material.Attribute
  alias Platform.Auditor

  def update(assigns, socket) do
    attr = Attribute.get_attribute(String.to_atom(assigns.name))

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:attr, attr)
     |> assign(
       :changeset,
       Material.change_media_attribute(assigns.media, attr, assigns.current_user)
     )}
  end

  def close(socket) do
    socket |> push_patch(to: Routes.media_show_path(socket, :show, socket.assigns.media.slug))
  end

  defp has_changes(changeset) do
    map_size(changeset.changes) > 0
  end

  defp inject_attr_field_if_missing(params, %Attribute{} = attr) do
    Map.put_new(params, attr.schema_field |> Atom.to_string(), nil)
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, close(socket)}
  end

  def handle_event("save", input, socket) do
    # To allow empty strings, lists, etc.
    params = Map.get(input, "media", %{}) |> inject_attr_field_if_missing(socket.assigns.attr)

    case Material.update_media_attribute_audited(
           socket.assigns.media,
           socket.assigns.attr,
           socket.assigns.current_user,
           params
         ) do
      {:ok, media} ->
        Auditor.log(
          :attribute_updated,
          Map.merge(params, %{media_slug: media.slug}),
          socket
        )

        {:noreply, socket |> put_flash(:info, "Your update has been saved.") |> close()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("validate", input, socket) do
    # To allow empty strings, lists, etc.
    params = Map.get(input, "media", %{}) |> inject_attr_field_if_missing(socket.assigns.attr)

    changeset =
      socket.assigns.media
      |> Material.change_media_attribute(socket.assigns.attr, socket.assigns.current_user, params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def render(assigns) do
    confirm_prompt = "This will discard your changes without saving. Are you sure?"
    disabled = !has_changes(assigns.changeset)

    ~H"""
    <article>
      <.modal target={@myself} close_confirmation={confirm_prompt}>
        <p class="support font-mono"><%= @media.slug %></p>
        <h3 class="sec-head"><%= @attr.label %></h3>
        <p class="sec-subhead"><%= @attr.description %></p>
        <hr class="h-8 sep" />
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
              <%= case @attr.type do %>
                <% :text -> %>
                  <%= label(f, @attr.schema_field, @attr.label) %>
                  <%= textarea(f, @attr.schema_field) %>
                <% :select -> %>
                  <div phx-update="ignore" id={"attr_select_#{@media.slug}_#{@attr.schema_field}"}>
                    <%= label(f, @attr.schema_field, @attr.label) %>
                    <%= error_tag(f, @attr.schema_field) %>
                    <%= select(f, @attr.schema_field, ["[Unset]": nil] ++ Attribute.options(@attr)) %>
                  </div>
                <% :multi_select -> %>
                  <%= label(f, @attr.schema_field, @attr.label) %>
                  <%= error_tag(f, @attr.schema_field) %>
                  <div
                    phx-update="ignore"
                    id={"attr_multi_select_#{@media.slug}_#{@attr.schema_field}"}
                  >
                    <%= multiple_select(f, @attr.schema_field, Attribute.options(@attr)) %>
                  </div>
                <% :location -> %>
                  <div class="space-y-4">
                    <div>
                      <%= label(f, :latitude, "Latitude") %>
                      <%= text_input(f, :latitude,
                        placeholder: "Lat, e.g., 37.4286969",
                        novalidate: true
                      ) %>
                      <%= error_tag(f, :latitude) %>
                    </div>
                    <div>
                      <%= label(f, :longitude, "Longitude") %>
                      <%= text_input(f, :longitude,
                        placeholder: "Lon, e.g., -122.1721319",
                        novalidate: true
                      ) %>
                      <%= error_tag(f, :longitude) %>
                    </div>
                    <%= error_tag(f, @attr.schema_field) %>
                  </div>
                <% :time -> %>
                  <%= label(f, @attr.schema_field, @attr.label) %>
                  <div class="flex items-center gap-2 ts-ignore sm:w-64 apply-a17t-fields">
                    <%= time_select(f, @attr.schema_field,
                      hour: [prompt: "[Unset]"],
                      minute: [prompt: "[Unset]"],
                      class: "select"
                    ) %>
                  </div>
                  <p class="support">
                    To unset this attribute, set both the hour and minute fields to [Unset].
                  </p>
                  <%= error_tag(f, @attr.schema_field) %>
                <% :date -> %>
                  <%= label(f, @attr.schema_field, @attr.label) %>
                  <div class="flex items-center gap-2 ts-ignore apply-a17t-fields">
                    <%= date_select(f, @attr.schema_field,
                      year: [prompt: "[Unset]", options: DateTime.utc_now().year..1990],
                      month: [prompt: "[Unset]"],
                      day: [prompt: "[Unset]"],
                      class: "select"
                    ) %>
                  </div>
                  <p class="support">
                    To unset this attribute, set the day, month, and year fields to [Unset].
                  </p>
                  <%= error_tag(f, @attr.schema_field) %>
              <% end %>
              <% val =
                Map.get(@changeset.changes, @attr.schema_field, Map.get(@media, @attr.schema_field)) %>
              <%= if @attr.type == :location and val.coordinates |> Tuple.to_list |> Enum.all?(&(is_float(&1))) do %>
                <% {lon, lat} = val.coordinates %>
                <a
                  class="support text-urge-700 underline mt-4"
                  target="_blank"
                  href={"https://maps.google.com/maps?q=#{lat},#{lon}"}
                >
                  Preview
                  <span class="font-bold">
                    <.location lat={lat} lon={lon} />
                  </span>
                  on Google Maps
                </a>
              <% end %>
            </div>
            <div>
              <%= label(f, :explanation, "Briefly Explain Your Change") %>
              <%= textarea(f, :explanation,
                phx_debounce: "blur",
                placeholder: "Recommended for all non-trivial changes.",
                class: "my-1"
              ) %>
              <%= error_tag(f, :explanation) %>
            </div>
            <div class="flex md:justify-between">
              <%= submit("Post update →",
                phx_disable_with: "Saving...",
                class: "button ~urge @high",
                disabled: disabled
              ) %>
              <button
                phx-click="close_modal"
                phx-target={@myself}
                data-confirm={confirm_prompt}
                type="button"
                class="base-button"
              >
                Cancel
              </button>
            </div>
          </div>
        </.form>
      </.modal>
    </article>
    """
  end
end
