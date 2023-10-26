defmodule PlatformWeb.MediaLive.LinkVersionLive do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Auditor
  alias Platform.Permissions

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_version()
     |> assign_source_url_duplicate(%{})
     |> assign_changeset()}
  end

  defp assign_version(socket) do
    socket |> assign(:version, %Material.MediaVersion{media: socket.assigns.media})
  end

  defp assign_changeset(socket) do
    socket
    |> assign_new(:changeset, fn -> Material.change_media_version(socket.assigns.version) end)
  end

  defp assign_source_url_duplicate(socket, params) do
    source_url = Map.get(params, "source_url", "")

    if String.length(source_url) > 0 do
      socket
      |> assign(
        :url_duplicate_of,
        Material.get_media_by_source_url(source_url, for_user: socket.assigns.current_user)
        |> Enum.filter(&Permissions.can_view_media?(socket.assigns.current_user, &1))
      )
    else
      socket |> assign(:url_duplicate_of, [])
    end
  end

  defp set_fixed_params(params, socket) do
    params
    |> Map.put("media_id", socket.assigns.media.id)
    |> Map.put("status", "pending")
    |> Map.put("upload_type", "direct")
  end

  defp apply_changeset(version, params) do
    Material.change_media_version(version, params)
  end

  def handle_event("validate", %{"media_version" => params}, socket) do
    params = params |> set_fixed_params(socket)

    changeset =
      socket.assigns.version
      |> apply_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset) |> assign_source_url_duplicate(params)}
  end

  def handle_event("save", %{"media_version" => params}, socket) do
    params = params |> set_fixed_params(socket)

    changeset =
      socket.assigns.version
      |> apply_changeset(params)
      |> Map.put(:action, :validate)

    if changeset.valid? do
      case Material.create_media_version_audited(
             socket.assigns.media,
             socket.assigns.current_user,
             params
           ) do
        {:ok, version} ->
          Auditor.log(
            :media_version_uploaded,
            Map.merge(params, %{media_slug: socket.assigns.media.slug}),
            socket
          )

          # Start archival
          Material.archive_media_version(version)

          # Wrap up
          send(self(), {:version_add_complete, version})
          {:noreply, socket |> assign(:disabled, true)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :changeset, changeset)}
      end
    else
      {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("close_modal", _params, socket) do
    send(self(), {:version_add_complete, nil})
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <article>
      <.form
        :let={f}
        for={@changeset}
        id="media-upload"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="phx-form"
      >
        <div class="space-y-6">
          <div>
            <%= label(f, :source_url, "What is the link to the media you would like to upload?") %>
            <%= url_input(f, :source_url, placeholder: "https://twitter.com/...", phx_debounce: "250") %>
            <p class="support">
              Add a link and Atlos will add it to the incident and attempt to archive it automatically.
            </p>
            <%= error_tag(f, :source_url) %>
            <%= if length(@url_duplicate_of) > 0 do %>
              <.deconfliction_warning duplicates={@url_duplicate_of} current_user={@current_user} />
            <% end %>
          </div>
          <div>
            <%= label(f, :explanation, "Briefly Explain Your Addition") %>
            <div class="border border-gray-300 rounded shadow-sm overflow-hidden focus-within:border-urge-500 focus-within:ring-1 focus-within:ring-urge-500 transition">
              <.interactive_textarea
                form={f}
                disabled={false}
                name={:explanation}
                placeholder="Optionally provide more context on this media."
                id="comment-box-parent-input"
                rows={1}
                class="block w-full !border-0 resize-none focus:ring-0 sm:text-sm shadow-none"
              />
            </div>
            <%= error_tag(f, :explanation) %>
          </div>
          <div class="flex flex-col sm:flex-row gap-4 justify-between sm:items-center">
            <%= submit(
              "Publish to Atlos",
              phx_disable_with: "Uploading...",
              class: "button ~urge @high"
            ) %>
            <.link navigate={"/incidents/#{@media.slug}/"} class="text-button text-sm text-right">
              Or cancel media upload
              <span class="text-gray-500 font-normal block text-xs">
                You can upload media later
              </span>
            </.link>
          </div>
        </div>
      </.form>
    </article>
    """
  end
end
