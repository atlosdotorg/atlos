defmodule PlatformWeb.MediaLive.CommentBox do
  use PlatformWeb, :live_component
  alias Platform.Accounts
  alias Platform.Updates
  alias Platform.Uploads
  alias Platform.Auditor

  def mount(socket) do
    Temp.track!()

    {:ok,
     socket
     |> allow_upload(:attachments,
       accept: ~w(.png .jpg .jpeg .pdf .gif),
       max_entries: 9,
       max_file_size: 10_000_000,
       auto_upload: false,
       progress: &handle_progress/3
     )
     |> assign_new(:disabled, fn -> false end)
     |> assign_new(:render_id, fn -> Platform.Utils.generate_random_sequence(5) end)}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_changeset()}
  end

  def handle_progress(:attachments, _entry, socket) do
    {:noreply, socket}
  end

  def reset_state(socket) do
    socket
    |> assign(
      :changeset,
      Updates.change_from_comment(socket.assigns.media, socket.assigns.current_user)
    )
    |> assign(:render_id, Platform.Utils.generate_random_sequence(5))
  end

  defp assign_changeset(socket) do
    socket
    |> assign_new(
      :changeset,
      fn -> Updates.change_from_comment(socket.assigns.media, socket.assigns.current_user) end
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
    # First, we create a "dummy" changeset to make sure everything is valid, minus attachments
    changeset =
      Updates.change_from_comment(
        socket.assigns.media,
        socket.assigns.current_user,
        params
      )

    # If it is valid, we consume the uploads as attachments
    attachments =
      if changeset.valid? do
        consume_uploaded_entries(socket, :attachments, fn %{path: path}, entry ->
          # Copying it to _another_ temporary path helps ensure we remove the user's provided filename
          to_path =
            Temp.path!(
              prefix: socket.assigns.current_user.username,
              suffix: "." <> hd(MIME.extensions(entry.client_type))
            )

          File.cp!(path, to_path)
          Uploads.UpdateAttachment.store({to_path, socket.assigns.media})
        end)
      else
        nil
      end

    # ...and then generate the final changeset, with attachments
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
        Auditor.log(
          :comment_created,
          Map.merge(changeset.changes, %{media_slug: socket.assigns.media.slug}),
          socket
        )

        Updates.subscribe_if_first_interaction(socket.assigns.media, socket.assigns.current_user)

        {:noreply,
         socket
         |> put_flash(:info, "Your comment has been posted.")
         |> reset_state()
         |> push_patch(to: Routes.media_show_path(socket, :show, socket.assigns.media.slug))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(:changeset, changeset)}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to post your comment.")}
    end
  end

  def handle_event("recover", %{"update" => _params} = input, socket) do
    handle_event("validate", input, socket)
  end

  def handle_event("validate", %{"update" => params} = _input, socket) do
    # If they are reconnecting, we want to preserve the old content — and not rerender
    render_id = Map.get(params, "render_id", socket.assigns.render_id)

    changeset =
      Updates.change_from_comment(
        socket.assigns.media,
        socket.assigns.current_user,
        params
      )
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset) |> assign(:render_id, render_id)}
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
        :let={f}
        for={@changeset}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        id="comment-box-form"
        phx-auto-recover="recover"
      >
        <%!-- For form recovery --%>
        <%= hidden_input(f, :render_id, value: @render_id) %>
        <div class="flex items-start space-x-4">
          <div class="flex-shrink-0" phx-update="ignore" id="comment-box-profile-photo">
            <img
              class="inline-block h-10 w-10 rounded-full"
              src={Accounts.get_profile_photo_path(@current_user)}
              alt="Your profile photo"
            />
          </div>
          <div class="min-w-0 grow">
            <div class="relative">
              <div class="-ml-1 border border-gray-300 rounded-lg shadow-sm overflow-hidden focus-within:border-urge-500 focus-within:ring-1 focus-within:ring-urge-500 transition pt-1">
                <label for="comment" class="sr-only">Add a comment...</label>
                <.interactive_textarea
                  disabled={@disabled}
                  form={f}
                  name={:explanation}
                  required={true}
                  model="content"
                  placeholder={
                    if(@disabled,
                      do: "Commenting has been disabled",
                      else: "Add a comment..."
                    )
                  }
                  id={"comment-parent-input-#{@render_id}"}
                  rows={4}
                  class="!border-0 resize-none focus:ring-0 sm:text-sm shadow-none"
                />

                <section class="grid grid-cols-2 md:grid-cols-3 gap-2 p-2">
                  <%= for entry <- @uploads.attachments.entries do %>
                    <article class="upload-entry relative rounded group self-start">
                      <div
                        role="status"
                        class="w-full h-full top-0 absolute bg-[#00000050] phx-only-during-submit"
                      >
                        <div class="flex items-center justify-around h-full w-full">
                          <svg
                            aria-hidden="true"
                            class="mr-2 w-8 h-8 text-gray-100 animate-spin fill-urge-600"
                            viewBox="0 0 100 101"
                            fill="none"
                            xmlns="http://www.w3.org/2000/svg"
                          >
                            <path
                              d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z"
                              fill="currentColor"
                            />
                            <path
                              d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z"
                              fill="currentFill"
                            />
                          </svg>
                          <span class="sr-only">Uploading...</span>
                        </div>
                      </div>
                      <figure class="rounded">
                        <%= if entry.client_type == "application/pdf" do %>
                          <.document_preview
                            file_name={entry.client_name}
                            description="The file's name won't be published."
                          />
                        <% else %>
                          <.live_img_preview entry={entry} />
                        <% end %>
                      </figure>

                      <button
                        type="button"
                        phx-click="cancel_upload"
                        phx-value-ref={entry.ref}
                        phx-target={@myself}
                        aria-label="cancel"
                        class="absolute top-0 left-0 -ml-2 -mt-2 bg-white rounded-full text-gray-400 phx-only-during-reg"
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
                  <div class="md:flex items-center">
                    <.live_file_input upload={@uploads.attachments} class="sr-only" />
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

                    <span class="phx-form md:ml-2">
                      <%= error_tag(f, :explanation) %>
                      <%= error_tag(f, :attachments) %>
                    </span>
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
