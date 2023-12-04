defmodule PlatformWeb.MediaLive.EditAttribute do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Material.Attribute
  alias Platform.Auditor

  def update(assigns, socket) do
    attr = Attribute.get_attribute(assigns.name, project: assigns.media.project)

    if is_nil(attr) do
      raise PlatformWeb.Errors.NotFound, "Attribute not found"
    end

    attributes = [attr] ++ Attribute.get_children(attr.name)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:attrs, attributes)
     |> assign_new(
       :changeset,
       fn ->
         Material.change_media_attributes(assigns.media, attributes, %{},
           user: assigns.current_user
         )
       end
     )}
  end

  def close(socket, updated_media \\ nil) do
    if Map.get(socket.assigns, :target) do
      send(socket.assigns.target, {:end_attribute_edit, updated_media})
      socket
    else
      socket
      |> push_patch(
        to: Routes.media_show_path(socket, :show, socket.assigns.media.slug),
        replace: true
      )
    end
  end

  defp inject_attr_fields_if_missing(params, attrs) do
    Enum.reduce(attrs, params, fn attr, acc ->
      Map.put_new(acc, attr.schema_field |> Atom.to_string(), nil)
    end)
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, close(socket)}
  end

  def handle_event("save", input, socket) do
    # To allow empty strings, lists, etc.
    params = Map.get(input, "media", %{}) |> inject_attr_fields_if_missing(socket.assigns.attrs)

    case Material.update_media_attributes_audited(
           socket.assigns.media,
           socket.assigns.attrs,
           params,
           user: socket.assigns.current_user
         ) do
      {:ok, media} ->
        Auditor.log(
          :attribute_updated,
          Map.merge(params, %{media_slug: media.slug}),
          socket
        )

        {:noreply, socket |> put_flash(:info, "Your update has been saved.") |> close(media)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset |> Map.put(:action, :validate))}
    end
  end

  def handle_event("validate", input, socket) do
    # To allow empty strings, lists, etc.
    params = Map.get(input, "media", %{}) |> inject_attr_fields_if_missing(socket.assigns.attrs)

    changeset =
      socket.assigns.media
      # When validating, don't require the change to exist (that will be validated on submit)
      |> Material.change_media_attributes(
        socket.assigns.attrs,
        params,
        user: socket.assigns.current_user
      )
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def render(assigns) do
    confirm_prompt = "This will discard your changes without saving. Are you sure?"

    assigns = assign(assigns, :confirm_prompt, confirm_prompt)

    ~H"""
    <article>
      <.modal target={@myself} close_confirmation={@confirm_prompt}>
        <div class="md:flex justify-between">
          <div>
            <p class="support font-mono"><%= @media.slug %></p>
            <h3 class="sec-head">Update: <%= hd(@attrs).label %></h3>
            <p class="sec-subhead"><%= hd(@attrs).description %></p>
          </div>
        </div>
        <hr class="h-8 sep" />
        <%= if hd(@attrs).schema_field == :attr_status and Enum.member?(@media.attr_tags || [], "Volunteer") do %>
          <div class="rounded-md bg-blue-50 p-4 mb-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <Heroicons.information_circle mini class="h-5 w-5 text-blue-600" />
              </div>
              <div class="ml-3 flex-1 md:flex md:justify-between">
                <p class="text-sm text-blue-700">
                  <span class="font-medium">This is a volunteer-created incident.</span>
                  It may require additional review during the verification process.
                </p>
              </div>
            </div>
          </div>
        <% end %>
        <.form
          :let={f}
          for={@changeset}
          id={"#{hd(@attrs).schema_field}-attribute-form"}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
          class="phx-form"
        >
          <div class="space-y-6">
            <.edit_attributes
              attrs={@attrs}
              form={f}
              media_slug={@media.slug}
              media={@media}
              project={@media.project}
            />
            <% unset_attrs =
              Attribute.unset_for_media(@media, pane: :attributes, project: @media.project) %>
            <%= if hd(@attrs).schema_field == :attr_status and not Enum.empty?(unset_attrs) and @media.attr_status != "Completed" and Ecto.Changeset.get_change(f.source, :attr_status) == "Completed" do %>
              <div class="rounded-md bg-neutral-50 border p-4 mb-4">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <Heroicons.information_circle mini class="h-5 w-5 text-neutral-600" />
                  </div>
                  <div class="ml-3 -mt-px prose prose-sm">
                    <p>
                      <strong>Some information about this incident is missing.</strong>
                      You can still make this change, but note that the following <%= if length(unset_attrs) == 1,
                        do: "field is",
                        else: "fields are" %> not set: <i><%= Enum.join(Enum.map(unset_attrs, &(&1.label)), ", ") %></i>.
                    </p>
                  </div>
                </div>
              </div>
            <% end %>
            <div>
              <%= label(f, :explanation, "Briefly Explain Your Change") %>
              <div class="border border-gray-300 rounded shadow-sm overflow-hidden focus-within:border-urge-500 focus-within:ring-1 focus-within:ring-urge-500 transition">
                <.interactive_textarea
                  form={f}
                  disabled={false}
                  name={:explanation}
                  placeholder="Recommended for all non-trivial changes."
                  id="comment-box-parent-input"
                  rows={1}
                  class="block w-full !border-0 resize-none focus:ring-0 sm:text-sm shadow-none"
                />
              </div>
              <%= error_tag(f, :explanation) %>
            </div>
            <div class="flex md:justify-between">
              <%= submit("Post update →",
                phx_disable_with: "Saving...",
                class: "button ~urge @high transition-all mr-2"
              ) %>
              <button x-on:click="closeModal()" type="button" class="base-button">
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
