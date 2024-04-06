defmodule PlatformWeb.MediaLive.UploadVersionLive do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Utils
  alias Platform.Auditor
  alias Platform.Uploads
  alias Platform.Permissions

  def mount(socket) do
    {:ok,
     socket
     |> assign(:form_id, Utils.generate_random_sequence(10))
     |> allow_upload(:media_upload,
       accept: :any,
       max_entries: 1,
       max_file_size: 250_000_000,
       auto_upload: false,
       progress: &handle_progress/3,
       chunk_size: 512_000
     )
     |> assign(:processing, false)
     |> assign_source_url_duplicate(%{})
     |> clear_error()}
  end

  def update(assigns, socket) do
    # Track temporary files so they are properly cleaned up later
    Temp.track!()

    {:ok,
     socket
     |> assign(assigns)
     |> assign_version()
     |> assign_changeset()}
  end

  defp assign_version(socket) do
    socket |> assign_new(:version, fn -> %Material.MediaVersion{media: socket.assigns.media} end)
  end

  defp assign_changeset(socket) do
    socket
    |> assign_new(:changeset, fn -> Material.change_media_version(socket.assigns.version) end)
  end

  defp handle_static_file(%{path: path}, client_name) do
    to_path = Path.join(Temp.mkdir!(), Utils.slugify(client_name))
    File.cp!(path, to_path)
    {:ok, to_path}
  end

  defp clear_error(socket) do
    socket |> assign(:error, nil)
  end

  defp set_fixed_params(params, socket) do
    params
    |> Map.put("media_id", socket.assigns.media.id)
    |> Map.put("status", "pending")
    |> Map.put("upload_type", "user_provided")
  end

  defp assign_source_url_duplicate(socket, params) do
    source_url = Map.get(params, "source_url", "")

    if String.length(source_url) > 0 do
      socket
      |> assign(
        :url_duplicate_of,
        Material.get_media_by_source_url(source_url, for_user: socket.assigns.current_user)
        |> Permissions.filter_to_viewable_media(socket.assigns.current_user)
      )
    else
      socket |> assign(:url_duplicate_of, [])
    end
  end

  def handle_event("validate", %{"media_version" => params}, socket) do
    params = params |> set_fixed_params(socket)

    changeset =
      socket.assigns.version
      |> Material.change_media_version(params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign_source_url_duplicate(params)
     |> clear_error()}
  end

  def handle_event("save", %{"media_version" => params}, socket) do
    params = params |> set_fixed_params(socket)

    changeset =
      socket.assigns.version
      |> Material.change_media_version(params)
      |> Map.put(:action, :validate)

    # This is a bit of a hack, but we only want to handle the uploaded media if everything else is OK.
    # So we *manually* check to verify the source URL is correct before proceeding.
    ugc_invalid =
      not changeset.valid? ||
        Enum.empty?(socket.assigns.uploads.media_upload.entries)

    if ugc_invalid do
      {:noreply,
       socket
       |> assign(:changeset, changeset)
       |> assign(:error, "Please be sure to provide a photo or video and its source link.")}
    else
      entry = hd(socket.assigns.uploads.media_upload.entries)

      # Upload the provided file to S3
      local_path =
        consume_uploaded_entry(
          socket,
          entry,
          &handle_static_file(&1, entry.client_name)
        )

      pid = self()

      Task.start(fn ->
        try do
          artifact_id = Ecto.UUID.generate()
          %{size: size} = File.stat!(local_path)

          # Store the file in S3
          {:ok, remote_path} =
            Uploads.MediaVersionArtifact.store({local_path, %{id: artifact_id}})

          # Update the media version
          {:ok, version} =
            Material.create_media_version_audited(
              socket.assigns.media,
              socket.assigns.current_user,
              Map.merge(params, %{
                "artifacts" => [
                  %{
                    "id" => artifact_id,
                    "file_location" => remote_path,
                    "file_hash_sha256" => Platform.Utils.hash_sha256(local_path),
                    "file_size" => size,
                    "mime_type" => MIME.from_path(local_path),
                    "type" => "upload"
                  }
                ]
              })
            )

          Material.archive_media_version(version)

          Auditor.log(
            :media_version_uploaded,
            Map.merge(params, %{media_slug: socket.assigns.media.slug}),
            socket
          )

          send(pid, {:version_add_complete, version})
        rescue
          error ->
            Auditor.log(
              :direct_media_version_processing_failure,
              Map.merge(params, %{media_slug: socket.assigns.media.slug, error: inspect(error)}),
              socket
            )

            send(pid, {:version_creation_failed, changeset})
        end
      end)

      {:noreply, socket |> assign(:processing, true)}
    end
  end

  def handle_event("close_modal", _params, socket) do
    send(self(), {:version_add_complete, nil})
    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media_upload, ref)}
  end

  def handle_progress(:media_upload, _entry, socket) do
    {:noreply, socket}
  end

  defp friendly_error(:too_large),
    do: "This file is too large; the maximum size is 250 megabytes."

  defp friendly_error(:not_accepted),
    do:
      "The file type you are uploading is not supported. Please contact us if you think this is an error."

  def render(assigns) do
    active_uploads = Enum.filter(assigns.uploads.media_upload.entries, &(!&1.cancelled?))

    assigns =
      assign(
        assigns,
        :active_uploads,
        active_uploads
      )

    is_uploading = length(active_uploads) > 0

    is_invalid = Enum.any?(assigns.uploads.media_upload.entries, &(!&1.valid?))

    assigns =
      assign(
        assigns,
        :cancel_upload,
        if is_uploading do
          ~H"""
          <button
            phx-click="cancel_upload"
            phx-target={@myself}
            phx-value-ref={hd(@active_uploads).ref}
            class="text-sm label ~neutral"
            type="button"
          >
            Cancel Upload
          </button>
          """
        end
      )
      |> assign(:is_uploading, is_uploading)
      |> assign(:is_invalid, is_invalid)

    ~H"""
    <article>
      <%= if @error do %>
        <aside class="aside ~critical mb-4">
          <%= @error %>
        </aside>
      <% end %>
      <.form
        :let={f}
        for={@changeset}
        id={"media-upload-#{@form_id}"}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class={"phx-form " <> if @processing, do: "phx-submit-loading", else: ""}
      >
        <div class="space-y-6">
          <div
            class="w-full flex justify-center items-center px-6 pt-5 pb-6 border-2 h-40 border-gray-300 border-dashed rounded-md"
            phx-drop-target={@uploads.media_upload.ref}
          >
            <.live_file_input upload={@uploads.media_upload} class="sr-only" />
            <div class="phx-only-during-submit">
              <div class="space-y-1 text-center">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="mx-auto h-12 w-12 text-urge-400 animate-spin"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
                  />
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                  />
                </svg>
                <div class="w-full text-sm text-gray-600">
                  <div class="w-42 mt-2 text-center">
                    <p class="font-medium text-neutral-800 mb-1">Processing your media...</p>
                    <p>
                      This might take a moment. You will be redirected to the incident once the upload is complete.
                    </p>
                  </div>
                </div>
              </div>
            </div>
            <div class="phx-only-during-reg">
              <%= cond do %>
                <% @is_invalid -> %>
                  <div class="space-y-1 text-center">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="mx-auto h-12 w-12 text-critical-600"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                      />
                    </svg>
                    <div class="w-full text-sm text-gray-600">
                      <p>Something went wrong while processing your upload.</p>
                      <%= for entry <- @uploads.media_upload.entries do %>
                        <%= for err <- upload_errors(@uploads.media_upload, entry) do %>
                          <p class="my-2"><%= friendly_error(err) %></p>
                        <% end %>
                      <% end %>
                      <label
                        for={@uploads.media_upload.ref}
                        class="relative cursor-pointer bg-white rounded-md font-medium !text-urge-600 hover:text-urge-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-urge-500"
                      >
                        <span>Upload another file</span>
                      </label>
                    </div>
                  </div>
                <% @is_uploading -> %>
                  <div class="space-y-1 text-center w-full">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      aria-hidden="true"
                      class="mx-auto h-12 w-12 text-gray-400"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"
                      />
                    </svg>
                    <div class="w-full text-sm text-gray-600">
                      <%= for entry <- @uploads.media_upload.entries do %>
                        <div class="w-42 mt-4 text-center">
                          <p>Selected: <%= Utils.truncate(entry.client_name) %></p>
                        </div>
                      <% end %>
                    </div>
                    <%= if not @processing do %>
                      <div>
                        <%= @cancel_upload %>
                      </div>
                    <% end %>
                  </div>
                <% true -> %>
                  <div class="space-y-1 text-center">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      aria-hidden="true"
                      class="mx-auto h-12 w-12 text-gray-400"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"
                      />
                    </svg>
                    <div class="flex text-sm text-gray-600 justify-center">
                      <label
                        for={@uploads.media_upload.ref}
                        class="relative cursor-pointer bg-white rounded-md font-medium !text-urge-600 hover:text-urge-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-urge-500"
                      >
                        <span>Upload a file</span>
                      </label>
                      <p class="pl-1 text-center">or drag and drop</p>
                    </div>
                    <p class="text-xs text-gray-500">Any file up to 250MB</p>
                  </div>
              <% end %>
            </div>
          </div>
          <%= if not @processing do %>
            <div>
              <%= label(f, :source_url, "Where did this media come from? (Optional)") %>
              <%= url_input(f, :source_url,
                placeholder: "https://example.com/...",
                phx_debounce: "250"
              ) %>
              <p class="support">
                This might be a tweet, a Telegram message, or something else. Where did the media come from?
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
            </div>
          <% end %>
        </div>
      </.form>
    </article>
    """
  end
end
