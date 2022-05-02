defmodule PlatformWeb.MediaLive.CommentBox do
  use PlatformWeb, :live_component
  alias Platform.Accounts
  alias Platform.Updates
  alias Platform.Uploads
  alias Platform.Utils
  alias Phoenix.LiveView.Upload

  def update(assigns, socket) do
    Temp.track!()

    {:ok,
     socket
     |> assign(assigns)
     # Clear uploads from previous render
     |> Upload.maybe_cancel_uploads()
     |> Kernel.elem(0)
     |> assign_new(:disabled, fn -> false end)
     |> allow_upload(:attachments,
       accept: ~w(.png .jpg .jpeg),
       max_entries: 9,
       max_file_size: 10_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )
     |> assign_changeset()}
  end

  def handle_progress(:attachments, _entry, socket) do
    {:noreply, socket}
  end

  defp handle_static_file(%{path: path}) do
    # Just make a copy of the file; all the real processing is done later in handle_uploaded_file.
    to_path = Temp.path!(prefix: Utils.generate_random_sequence(10))
    File.cp!(path, to_path)
    {:ok, to_path}
  end

  defp handle_uploaded_file(socket, entry) do
    path = consume_uploaded_entry(socket, entry, &handle_static_file(&1))

    {:ok, location} = Uploads.UpdateAttachment.store({path, socket.assigns.media})

    location
  end

  defp assign_changeset(socket) do
    socket
    |> assign(
      :changeset,
      Updates.change_from_comment(socket.assigns.media, socket.assigns.current_user)
    )
  end

  defp friendly_error(:too_large),
    do: "This file is too large; the maximum size is 50 megabytes."

  defp friendly_error(:not_accepted),
    do:
      "The file type you are uploading is not supported. Please contact us if you think this is an error."

  defp friendly_error(:too_many_files),
    do: "You have selected too many files. At most 9 are allowed."

  defp friendly_error(val), do: val

  def handle_event("save", %{"update" => params} = _input, socket) do
    attachments =
      consume_uploaded_entries(socket, :attachments, fn %{path: path}, _entry ->
        # Copying it to _another_ temporary path helps ensure we remove the user's provided filename
        to_path = Temp.path!(prefix: socket.assigns.current_user.username)
        File.cp!(path, to_path)
        Uploads.UpdateAttachment.store({to_path, socket.assigns.media})
      end)

    changeset =
      Updates.change_from_comment(
        socket.assigns.media,
        socket.assigns.current_user,
        Map.put(
          params,
          "attachments",
          attachments
        )
      )

    case Updates.create_update_from_changeset(changeset) do
      {:ok, _update} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your comment has been posted.")
         |> assign_changeset()
         |> push_patch(to: Routes.media_show_path(socket, :show, socket.assigns.media.slug))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(:changeset, changeset)}
    end
  end

  def handle_event("validate", %{"update" => params} = _input, socket) do
    changeset =
      Updates.change_from_comment(socket.assigns.media, socket.assigns.current_user, params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attachments, ref)}
  end

  def render(assigns) do
    ~H"""
    <section
      class="relative bg-white pt-2 mt-2"
      id={"#{@id}"}
      phx-drop-target={@uploads.attachments.ref}
    >
      <.form
        let={f}
        for={@changeset}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="pulse-form-on-submit"
      >
        <div class="flex items-start space-x-4">
          <div class="flex-shrink-0">
            <img
              class="inline-block h-10 w-10 rounded-full"
              src={Accounts.get_profile_photo_path(@current_user)}
              alt="Your profile photo"
            />
          </div>
          <div class="min-w-0 flex-1">
            <div class="relative">
              <div class="-ml-1 border border-gray-300 rounded-lg shadow-sm overflow-hidden focus-within:border-urge-500 focus-within:ring-1 focus-within:ring-urge-500">
                <label for="comment" class="sr-only">Add a comment...</label>
                <%= textarea(f, :explanation,
                  phx_debounce: 300,
                  rows: 4,
                  placeholder:
                    if(@disabled, do: "Commenting has been disabled", else: "Add your comment..."),
                  class: "block w-full py-3 border-0 resize-none focus:ring-0 sm:text-sm",
                  required: true,
                  disabled: @disabled,
                  id: "comment-input"
                ) %>

                <section class="grid grid-cols-2 md:grid-cols-3 gap-2 p-2">
                  <%= for entry <- @uploads.attachments.entries do %>
                    <article class="upload-entry relative rounded group">
                      <figure class="rounded">
                        <%= live_img_preview(entry) %>
                      </figure>

                      <button
                        type="button"
                        phx-click="cancel_upload"
                        phx-value-ref={entry.ref}
                        phx-target={@myself}
                        aria-label="cancel"
                        class="absolute top-0 left-0 -ml-2 -mt-2 bg-white rounded-full text-gray-400"
                      >
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          class="h-4 w-4"
                          viewBox="0 0 20 20"
                          fill="currentColor"
                        >
                          <path
                            fill-rule="evenodd"
                            d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                            clip-rule="evenodd"
                          />
                        </svg>
                      </button>

                      <%= for err <- upload_errors(@uploads.attachments, entry) do %>
                        <p class="support ~critical"><%= friendly_error(err) %></p>
                      <% end %>
                    </article>
                  <% end %>

                  <%= for err <- upload_errors(@uploads.attachments) do %>
                    <p class="support ~critical"><%= friendly_error(err) %></p>
                  <% end %>
                </section>
                <!-- Spacer element to match the height of the toolbar -->
                <div class="pt-1 pb-2" aria-hidden="true">
                  <!-- Matches height of button in toolbar (1px border + 36px content height) -->
                  <div class="py-px">
                    <div class="h-9"></div>
                  </div>
                </div>
              </div>

              <div class="absolute bottom-0 inset-x-0 pl-3 pr-2 pt-1 pb-2 flex justify-between">
                <div class="flex items-center space-x-5">
                  <div class="flex items-center">
                    <%= live_file_input(@uploads.attachments, class: "sr-only") %>
                    <button
                      type="button"
                      onclick={"document.getElementById('#{@uploads.attachments.ref}').click()"}
                      class="-m-2.5 w-10 h-10 rounded-full flex items-center justify-center text-gray-400 hover:text-gray-500"
                    >
                      <svg
                        class="h-5 w-5"
                        xmlns="http://www.w3.org/2000/svg"
                        viewBox="0 0 20 20"
                        fill="currentColor"
                        aria-hidden="true"
                      >
                        <path
                          fill-rule="evenodd"
                          d="M8 4a3 3 0 00-3 3v4a5 5 0 0010 0V7a1 1 0 112 0v4a7 7 0 11-14 0V7a5 5 0 0110 0v4a3 3 0 11-6 0V7a1 1 0 012 0v4a1 1 0 102 0V7a3 3 0 00-3-3z"
                          clip-rule="evenodd"
                        />
                      </svg>
                      <span class="sr-only">Attach a file</span>
                    </button>

                    <%= error_tag(f, :explanation) %>
                    <%= error_tag(f, :attachments) %>
                  </div>
                </div>
                <div class="flex-shrink-0">
                  <%= submit("Post",
                    phx_disable_with: "Posting...",
                    class: "button ~urge @high",
                    disabled: @disabled
                  ) %>
                </div>
              </div>
            </div>
          </div>
        </div>
      </.form>
    </section>
    """
  end
end
