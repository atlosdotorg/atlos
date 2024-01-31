defmodule PlatformWeb.MediaLive.CommentBox do
  use PlatformWeb, :live_component
  alias Platform.Accounts
  alias Platform.Updates
  alias Platform.Uploads
  alias Platform.Auditor

  # Note: the file upload logic is duplicated in `edit_attribute.ex`; if you change it, be sure to change `edit_attribute.ex` as well.
  def mount(socket) do
    Temp.track!()

    {:ok,
     socket
     |> allow_upload(:attachments,
       accept: ~w(.png .jpg .jpeg .pdf .gif .mp4),
       max_entries: 9,
       max_file_size: 50_000_000,
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
      x-data="{
        onPaste(event) {
          $refs.file_input.files = event.clipboardData.files;

          // We must manually trigger the input event so that Phoenix LiveView can pick up the changes
          // See https://goodtohear.co.uk/blog/post/Handle_Paste_Images_in_Phoenix_Live_View_Form_Uplo
          var event = document.createEvent('HTMLEvents');
          event.initEvent('input', true, true);
          $refs.file_input.dispatchEvent(event);
        }
      }"
    >
      <.form
        :let={f}
        for={@changeset}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        id="comment-box-form"
        phx-auto-recover="recover"
        x-on:paste="onPaste($event)"
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
                  class="!border-0 resize-none focus:ring-0 sm:text-sm shadow-none !bg-white"
                />
                <.display_uploads uploads={@uploads} myself={@myself} />
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
                    <.file_upload uploads={@uploads} />

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
