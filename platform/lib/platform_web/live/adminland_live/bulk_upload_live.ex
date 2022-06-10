defmodule PlatformWeb.AdminlandLive.BulkUploadLive do
  use PlatformWeb, :live_component

  alias Platform.Utils

  def update(_assigns, socket) do
    Temp.track!()

    {:ok,
     socket
     |> assign(:stage, "Upload incidents")
     |> assign(:processing, false)
     |> assign(:media_processing_error, false)
     |> assign(:uploaded_files, [])
     |> allow_upload(:bulk_upload,
       accept: ~w(.csv),
       max_entries: 1,
       max_file_size: 250_000_000,
       auto_upload: true,
       progress: &handle_progress/3,
       chunk_size: 512_000
     )}
  end

  defp friendly_error(:too_large),
    do: "This file is too large; the maximum size is 250 megabytes."

  defp friendly_error(:not_accepted),
    do: "The file type you are uploading is not supported. We only support CSV uploads."

  defp handle_progress(:bulk_upload, entry, socket) do
    if entry.done? do
      {:noreply, socket |> handle_uploaded_file(entry)}
    else
      {:noreply, socket}
    end
  end

  defp handle_static_file(%{path: path}) do
    # Just make a copy of the file; all the real processing is done later in handle_uploaded_file.
    to_path = Temp.path!()
    File.cp!(path, to_path)
    {:ok, to_path}
  end

  defp handle_uploaded_file(socket, entry) do
    path = consume_uploaded_entry(socket, entry, &handle_static_file(&1))

    socket |> assign(:stage, "Confirm information") |> assign(:upload_path, path)
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save", _params, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    uploads = Enum.filter(assigns.uploads.bulk_upload.entries, &(!&1.cancelled?))
    is_uploading = length(uploads) > 0

    is_invalid =
      Enum.any?(assigns.uploads.bulk_upload.entries, &(!&1.valid?)) or
        assigns.media_processing_error

    is_complete = Enum.any?(uploads, & &1.done?)

    cancel_upload =
      if is_uploading do
        ~H"""
        <button
          phx-click="cancel_upload"
          phx-target={@myself}
          phx-value-ref={hd(uploads).ref}
          class="text-sm label ~neutral"
          type="button"
        >
          Cancel Upload
        </button>
        """
      end

    ~H"""
    <section class="max-w-3xl mx-auto">
      <.card>
        <:header>
          <p class="sec-head">Bulk Upload</p>
          <p class="sec-subhead">Use this tool to upload new incidents in bulk.</p>
        </:header>
        <.stepper options={["Upload incidents", "Confirm information", "Publish"]} active={@stage} />
        <hr class="sep" />
        <%= case @stage do %>
          <% "Upload incidents" -> %>
            <form phx-change="validate" phx-submit="save" phx-target={@myself} id="upload-form">
              <div
                class="w-full flex justify-center items-center px-6 pt-5 pb-6 border-2 h-40 border-gray-300 border-dashed rounded-md"
                phx-drop-target={@uploads.bulk_upload.ref}
              >
                <%= live_file_input(@uploads.bulk_upload, class: "sr-only") %>
                <%= if @processing do %>
                  <div>
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
                          <p class="font-medium text-neutral-800 mb-1">Processing your upload...</p>
                          <p>
                            This might take a moment. Please keep the window open.
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>
                <% else %>
                  <%= cond do %>
                    <% is_complete -> %>
                      <div class="space-y-1 text-center phx-only-during-reg">
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          class="mx-auto h-12 w-12 text-positive-600"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                          stroke-width="2"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                          />
                        </svg>
                        <div class="w-full text-sm text-gray-600">
                          <%= for entry <- @uploads.bulk_upload.entries do %>
                            <div class="w-42 mt-4 text-center">
                              <p>Uploaded <%= Utils.truncate(entry.client_name) %>.</p>
                            </div>
                          <% end %>
                        </div>
                        <div>
                          <%= cancel_upload %>
                        </div>
                      </div>
                    <% is_invalid -> %>
                      <div class="space-y-1 text-center phx-only-during-reg">
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
                          <%= for entry <- @uploads.bulk_upload.entries do %>
                            <%= for err <- upload_errors(@uploads.bulk_upload, entry) do %>
                              <p class="my-2"><%= friendly_error(err) %></p>
                            <% end %>
                          <% end %>
                          <label
                            for={@uploads.bulk_upload.ref}
                            class="relative cursor-pointer bg-white rounded-md font-medium !text-urge-600 hover:text-urge-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-urge-500"
                          >
                            <span>Upload another file</span>
                          </label>
                        </div>
                      </div>
                    <% is_uploading -> %>
                      <div class="space-y-1 text-center w-full phx-only-during-reg">
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          aria-hidden="true"
                          class="mx-auto h-12 w-12 text-gray-400 animate-pulse"
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
                          <%= for entry <- @uploads.bulk_upload.entries do %>
                            <%= if entry.progress < 100 and entry.progress > 0 do %>
                              <div class="w-42 mt-4 text-center">
                                <p>Uploading <%= Utils.truncate(entry.client_name) %></p>
                                <progress value={entry.progress} max="100" class="progress ~urge mt-2">
                                  <%= entry.progress %>%
                                </progress>
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
                            for={@uploads.bulk_upload.ref}
                            class="relative cursor-pointer bg-white rounded-md font-medium !text-urge-600 hover:text-urge-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-urge-500"
                          >
                            <span>Upload a file</span>
                          </label>
                          <p class="pl-1 text-center">or drag and drop</p>
                        </div>
                        <p class="text-xs text-gray-500">CSV up to 250MB</p>
                      </div>
                  <% end %>
                <% end %>
              </div>
            </form>
          <% "Confirm information" -> %>
            TODO
        <% end %>
      </.card>
    </section>
    """
  end
end
