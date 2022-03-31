defmodule PlatformWeb.MediaLive.UploadVersionLive do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Utils

  def update(assigns, socket) do
    # Track temporary files so they are properly cleaned up later
    Temp.track!()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:media_processing_error, false)
     |> assign_version()
     # Internal params for uploaded data to keep in the form
     |> assign(:internal_params, %{})
     |> assign_changeset()
     |> assign(:form_id, Utils.generate_random_sequence(10))
     |> allow_upload(:media_upload,
       accept: ~w(.png .jpg .jpeg .avi .mp4 .webm),
       max_entries: 1,
       max_file_size: 250_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )
      |> clear_error()
    }
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

  defp handle_static_file(%{path: path}) do
    # Just make a copy of the file; all the real processing is done later in handle_uploaded_file.
    to_path = Temp.path!()
    File.cp!(path, to_path)
    {:ok, to_path}
  end

  defp assign_error(socket, error) do
    socket |> assign(:error, error)
  end

  defp clear_error(socket) do
    socket |> assign(:error, nil)
  end

  defp set_parent_media_in_params(params, socket) do
    Map.put(params, "media_id", socket.assigns.media.id)
  end

  def handle_event("validate", %{"media_version" => params}, socket) do
    params = params |> set_parent_media_in_params(socket)

    changeset =
      socket.assigns.version
      |> Material.change_media_version(params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset) |> clear_error()}
  end

  def handle_event("save", %{"media_version" => params}, socket) do
    params = params |> set_parent_media_in_params(socket)

    changeset =
      socket.assigns.version
      |> Material.change_media_version(params)
      |> Map.put(:action, :validate)

    # This is a bit of a hack, but we only want to handle the uploaded media if everything else is OK.
    # So we *manually* check to verify the source URL is correct before proceeding.
    ugc_invalid = Enum.any?([:source_url], &Keyword.has_key?(changeset.errors, &1)) || length(socket.assigns.uploads.media_upload.entries) == 0

    if ugc_invalid do
      {:noreply, socket |> assign(:changeset, changeset) |> assign(:error, "Please be sure to provide both a piece of media and a source link.")}
    else
      socket = socket |> clear_error() |> handle_uploaded_file(hd(socket.assigns.uploads.media_upload.entries))

      case Material.create_media_version(all_params(socket, params)) do
        {:ok, version} ->
          send(self(), {:version_created, version})
          {:noreply, socket |> assign(:disabled, true)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :changeset, changeset)}
      end
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media_upload, ref)}
  end

  defp handle_uploaded_file(socket, entry) do
    path = consume_uploaded_entry(socket, entry, &handle_static_file(&1))

    with {:ok, path, thumb_path, duration, size} <-
           Material.process_uploaded_media(path, entry.client_type, socket.assigns.media.slug) do
      socket
      |> update_internal_params("file_location", path)
      |> update_internal_params("duration_seconds", duration)
      |> update_internal_params("mime_type", entry.client_type)
      |> update_internal_params("thumbnail_location", thumb_path)
      |> update_internal_params("client_name", entry.client_name)
      |> update_internal_params("file_size", size)
    else
      {:error, _} ->
        socket
        |> assign(:media_processing_error, true)
    end
  end

  def handle_progress(:media_upload, _entry, socket) do
    {:noreply, socket}
  end

  defp truncate(str) do
    if String.length(str) > 30 do
      "#{String.slice(str, 0, 27) |> String.trim()}..."
    else
      str
    end
  end

  defp friendly_error(:too_large),
    do: "This file is too large; the maximum size is 250 megabytes."

  defp friendly_error(:not_accepted),
    do:
      "The file type you are uploading is not supported. Please contact us if you think this is an error."

  def render(assigns) do
    uploads = Enum.filter(assigns.uploads.media_upload.entries, &(!&1.cancelled?))
    is_uploading = length(uploads) > 0

    is_invalid =
      Enum.any?(assigns.uploads.media_upload.entries, &(!&1.valid?)) or
        assigns.media_processing_error

    is_complete = Enum.any?(uploads, & &1.done?)

    cancel_upload =
      if is_uploading do
        ~H"""
        <button phx-click="cancel_upload" phx-target={@myself} phx-value-ref={hd(uploads).ref} class="text-sm label ~neutral" type="button">Cancel Upload</button>
        """
      end

    ~H"""
    <article>
      <%= if @error do %>
        <aside class="aside ~critical mb-4">
          <%= @error %>
        </aside>
      <% end %>
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
          <div class="w-full flex justify-center items-center px-6 pt-5 pb-6 border-2 h-40 border-gray-300 border-dashed rounded-md" phx-drop-target={@uploads.media_upload.ref}>
            <%= live_file_input @uploads.media_upload, class: "sr-only" %>
            <div class="phx-only-during-submit">
              <div class="space-y-1 text-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto h-12 w-12 text-urge-400 animate-spin" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                  <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
                <div class="w-full text-sm text-gray-600">
                  <div class="w-42 mt-4 text-center">
                    <p>Processing your media (this might take a moment)...</p>
                  </div>
                </div>
              </div>
            </div>
            <%= cond do %>
            <% is_complete -> %>
              <div class="space-y-1 text-center phx-only-during-reg">
                <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto h-12 w-12 text-positive-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <div class="w-full text-sm text-gray-600">
                  <%= for entry <- @uploads.media_upload.entries do %>
                    <div class="w-42 mt-4 text-center">
                      <p>Uploaded <%= truncate(entry.client_name) %>.</p>
                    </div>
                  <% end %>
                </div>
                <div>
                  <%= cancel_upload %>
                </div>
              </div>
            <% is_invalid -> %>
              <div class="space-y-1 text-center phx-only-during-reg">
                <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto h-12 w-12 text-critical-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                </svg>
                <div class="w-full text-sm text-gray-600">
                  <p>Something went wrong while processing your upload.</p>
                  <%= for entry <- @uploads.media_upload.entries do %>
                    <%= for err <- upload_errors(@uploads.media_upload, entry) do %>
                      <p class="my-2"><%= friendly_error(err) %></p>
                    <% end %>
                  <% end %>
                  <label for={@uploads.media_upload.ref} class="relative cursor-pointer bg-white rounded-md font-medium !text-urge-600 hover:text-urge-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-urge-500">
                    <span>Upload another file</span>
                  </label>
                </div>
              </div>
            <% is_uploading -> %>
              <div class="space-y-1 text-center w-full phx-only-during-reg">
              <svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" class="mx-auto h-12 w-12 text-gray-400 animate-pulse" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
              </svg>
                <div class="w-full text-sm text-gray-600">
                  <%= for entry <- @uploads.media_upload.entries do %>
                    <%= if entry.progress < 100 and entry.progress > 0 do %>
                    <div class="w-42 mt-4 text-center">
                      <p>Uploading <%= truncate(entry.client_name) %></p>
                      <progress value={entry.progress} max="100" class="progress ~urge mt-2"> <%= entry.progress %>% </progress>
                    </div>
                    <% end %>
                  <% end %>
                </div>
                <div>
                  <%= cancel_upload %>
                </div>
              </div>
            <% true -> %>
              <div class="space-y-1 text-center phx-only-during-reg">
                <svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                </svg>
                <div class="flex text-sm text-gray-600 justify-center">
                  <label for={@uploads.media_upload.ref} class="relative cursor-pointer bg-white rounded-md font-medium !text-urge-600 hover:text-urge-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-urge-500">
                    <span>Upload a file</span>
                  </label>
                  <p class="pl-1 text-center">or drag and drop</p>
                </div>
                <p class="text-xs text-gray-500">PNG, JPG, GIF, MP4, or AVI up to 250MB</p>
              </div>
            <% end %>
          </div>
          <div>
            <%= label f, :source_url, "Where did this media come from?" %>
            <%= url_input f, :source_url, placeholder: "https://example.com/...", phx_debounce: "blur" %>
            <p class="support">This might be a Twitter post, a Telegram link, or something else. Where did the file come from?</p>
            <%= error_tag f, :source_url %>
          </div>
          <%= submit "Publish to Atlos", phx_disable_with: "Processing media...", class: "button ~urge @high" %>
        </div>
      </.form>
    </article>
    """
  end
end
