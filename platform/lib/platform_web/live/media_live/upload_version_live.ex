defmodule PlatformWeb.MediaLive.UploadVersionLive do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Utils

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_version()
     |> assign(:internal_params, %{}) # Internal params for uploaded data to keep in the form
     |> assign_changeset()
     |> assign(:form_id, Utils.generate_random_sequence(10))
     |> allow_upload(:media_upload,
      accept: ~w(.png .jpg .jpeg .gif .avi .mp4),
      max_entries: 1,
      max_file_size: 250_000_000,
      auto_upload: true,
      progress: &handle_progress/3
    )}
  end

  defp assign_version(socket) do
    socket |> assign(:version, %Material.MediaVersion{media: socket.assigns.media})
  end

  defp assign_changeset(socket) do
    socket |> assign(:changeset, Material.change_media_version(socket.assigns.version))
  end

  defp update_internal_params(socket, key, value) do
    socket |> assign(:internal_params, Map.put(socket.assigns.internal_params, key, value))
  end

  defp all_params(socket, params) do
    Map.merge(params, socket.assigns.internal_params)
  end

  defp upload_static_file(%{path: path}, socket) do
    Utils.upload_ugc_file(path, socket)
  end

  def handle_event("validate", %{"media_version" => params}, socket) do
    changeset =
      socket.assigns.version |> Material.change_media_version(params) |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"media_version" => params}, socket) do
    case Material.create_media_version(all_params(socket, params)) do
      {:ok, version} ->
        send(self(), {:version_created, version})
        {:noreply, socket |> assign(:disabled, true)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp handle_progress(:media_upload, entry, socket) do
    if entry.done? do
      path = consume_uploaded_entry(socket, entry, &upload_static_file(&1, socket))

      IO.puts "upload done"

      {:noreply,
       socket
       |> update_internal_params("file_location", path)
       |> update_internal_params("file_size", entry.client_size)
       |> update_internal_params("mime_type", entry.client_type)
       |> update_internal_params("client_name", entry.client_name)
       |> IO.inspect
      }
    else
      {:noreply, socket}
    end
  end

  defp friendly_error(:too_large), do: "This file is too large; the maximum size is 250 megabytes."
  defp friendly_error(:not_accepted), do: "The file type you are uploading is not supported. Please contact us if you think this is an error."

  def render(assigns) do
    ~H"""
    <article>
      <.form
        let={f}
        for={@changeset}
        id={"media-upload-#{@form_id}"}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="phx-form"
      >
        <div class="space-y-6">
          <div class="w-full flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md" phx-drop-target={@uploads.media_upload.ref}>
            <div class="space-y-1 text-center">
              <svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
              </svg>
              <div class="flex text-sm text-gray-600 justify-center">
                <label for="media_upload" class="relative cursor-pointer bg-white rounded-md font-medium !text-urge-600 hover:text-urge-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-urge-500">
                  <span>Upload a file</span>
                  <%= live_file_input @uploads.media_upload, class: "sr-only" %>
                </label>
                <p class="pl-1 text-center">or drag and drop</p>
              </div>
              <p class="text-xs text-gray-500">PNG, JPG, GIF, MP4, HEIC, or AVI up to 250MB</p>
            </div>

            <%= for entry <- @uploads.media_upload.entries do %>
              <%= if entry.progress < 100 and entry.progress > 0 do %>
                <% IO.inspect entry %>
                <progress value={entry.progress} max="100" class="progress ~urge mt-2"> <%= entry.progress %>% </progress>
              <% end %>
              <%= for err <- upload_errors(@uploads.media_upload, entry) do %>
                <p class="invalid-feedback mt-2"><%= friendly_error(err) %></p>
              <% end %>
            <% end %>
          </div>
          <div>
            <%= label f, :source_url, "Where did this media come from?" %>
            <%= url_input f, :source_url, placeholder: "https://example.com/..." %>
            <p class="support">This might be a Twitter post, a Telegram link, or something else. Where did the file come from?</p>
            <%= error_tag f, :source_url %>
          </div>
          <%= submit "Upload →", phx_disable_with: "Uploading...", class: "button ~urge @high", disabled: @changeset.changes == %{} %>
        </div>
      </.form>
    </article>
    """
  end
end
