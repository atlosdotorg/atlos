defmodule PlatformWeb.NewLive.BasicInfoLive do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Material.Attribute
  alias Platform.Auditor
  alias Platform.Accounts

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_media()
     |> assign(:disabled, false)
     |> assign_changeset()}
  end

  defp assign_media(socket) do
    socket |> assign(:media, %Material.Media{})
  end

  defp assign_changeset(socket) do
    socket
    |> assign(
      :changeset,
      Material.change_media(socket.assigns.media, %{}, socket.assigns.current_user)
    )
  end

  def handle_event("validate", %{"media" => _media_params}, socket) do
    # TODO: We don't currently do live validation because it causes the multiselect panel to jump around.
    # Given the time, it'd be nice to fix this.

    {:noreply, socket}
  end

  def handle_event("save", %{"media" => media_params}, socket) do
    case Material.create_media_audited(socket.assigns.current_user, media_params) do
      {:ok, media} ->
        {:ok, _} = Material.subscribe_user(media, socket.assigns.current_user)
        # We log here, rather than in the context, because we have access to the socket.
        # TODO: We should do the audit logging inside the context. We just need to sort out
        # the socket issue.
        Auditor.log(:media_created, Map.merge(media_params, %{media_slug: media.slug}), socket)
        send(self(), {:media_created, media})

        {:noreply,
         socket
         |> assign(:disabled, true)
         # We assign a changeset to prevent their changes from flickering during submit
         |> assign(
           :changeset,
           Material.change_media(socket.assigns.media, media_params, socket.assigns.current_user)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset |> Map.put(:action, :validate))}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <.form
        :let={f}
        for={@changeset}
        id="media-form"
        phx-target={@myself}
        phx-submit="save"
        class="phx-form"
      >
        <div class="space-y-6">
          <div>
            <.edit_attribute
              attr={Attribute.get_attribute(:description)}
              form={f}
              media_slug="NEW"
              media={nil}
            />
            <p class="support">
              Try to be as descriptive as possible. You'll be able to change this later.
            </p>
          </div>

          <div>
            <.edit_attribute
              attr={Attribute.get_attribute(:sensitive)}
              form={f}
              media_slug="NEW"
              media={nil}
            />
          </div>

          <div>
            <.edit_attribute
              attr={Attribute.get_attribute(:type)}
              form={f}
              media_slug="NEW"
              media={nil}
            />
          </div>

          <details class="p-4 rounded bg-neutral-100 mt-2">
            <summary class="text-button cursor-pointer transition-all">Additional attributes</summary>
            <div class="space-y-6 mt-4">
              <hr />
              <div>
                <.edit_attribute
                  attr={Attribute.get_attribute(:equipment)}
                  form={f}
                  media_slug="NEW"
                  media={nil}
                  optional={true}
                />
              </div>

              <div>
                <.edit_attribute
                  attr={Attribute.get_attribute(:impact)}
                  form={f}
                  media_slug="NEW"
                  media={nil}
                  optional={true}
                />
              </div>

              <div>
                <.edit_attribute
                  attr={Attribute.get_attribute(:date)}
                  form={f}
                  media_slug="NEW"
                  media={nil}
                  optional={true}
                />
              </div>

              <%= if Accounts.is_privileged(@current_user) do %>
                <div>
                  <.edit_attribute
                    attr={Attribute.get_attribute(:tags)}
                    form={f}
                    media_slug="NEW"
                    media={nil}
                    optional={true}
                  />
                </div>
              <% end %>
            </div>
          </details>

          <div class="md:flex gap-2 items-center justify-between">
            <%= submit("Create incident",
              phx_disable_with: "Saving...",
              class: "button ~urge @high",
              disabled: @disabled
            ) %>
            <p class="support text-neutral-600">You can upload media in the next step</p>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
