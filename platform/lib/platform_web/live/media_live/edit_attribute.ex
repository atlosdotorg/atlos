defmodule PlatformWeb.MediaLive.EditAttribute do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Material.Attribute
  alias Platform.Auditor
  alias Platform.Uploads

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

  def handle_progress(:attachments, _entry, socket) do
    {:noreply, socket}
  end

  defp friendly_error(:too_large),
    do: "This file is too large; the maximum size is 50 megabytes."

  defp friendly_error(:not_accepted),
    do:
      "The file type you are uploading is not supported. Please contact us if you think this is an error."

  defp friendly_error(:too_many_files),
    do: "You have selected too many files. At most 9 are allowed."

  defp friendly_error(val), do: val

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attachments, ref)}
  end

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

    attachments =
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

    params =
      Map.put(
        params,
        "attachments",
        attachments
      )

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
      <.modal target={@myself} close_confirmation={@confirm_prompt} no_pad={true}>
        <div class="md:flex justify-between border-b px-6 py-4">
          <div>
            <p class="support font-mono"><%= @media.slug %></p>
            <h3 class="sec-head mt-1"><%= hd(@attrs).label %></h3>
            <p class="sec-subhead text-neutral-500"><%= hd(@attrs).description %></p>
          </div>
        </div>
        <hr class="h-4 sep" />
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
          phx-drop-target={@uploads.attachments.ref}
          x-data="{
            onPaste(event) {
              $refs.file_input.files = event.clipboardData.files;
              var event = document.createEvent('HTMLEvents');
              event.initEvent('input', true, true);
              $refs.file_input.dispatchEvent(event);
            }
          }"
          x-on:paste="onPaste($event)"
        >
          <div class="mx-6 space-y-6">
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
                      You can still make this change, but note that the following <%= if length(
                                                                                           unset_attrs
                                                                                         ) == 1,
                                                                                         do:
                                                                                           "field is",
                                                                                         else:
                                                                                           "fields are" %> not set: <i><%= Enum.join(Enum.map(unset_attrs, &(&1.label)), ", ") %></i>.
                    </p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
          <div class="px-6 py-6 border-t mt-6 bg-neutral-50 rounded-b-lg">
            <%= label(f, :explanation, "Briefly Explain Your Change") %>
            <div class="border border-gray-300 rounded shadow-sm overflow-hidden focus-within:border-urge-500 focus-within:ring-1 min-h-[5rem] focus-within:ring-urge-500 transition mt !bg-white">
              <.interactive_textarea
                form={f}
                disabled={false}
                name={:explanation}
                placeholder="Recommended for all non-trivial changes."
                id="comment-box-parent-input"
                rows={1}
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
            <%= error_tag(f, :explanation) %>
            <div class="flex md:justify-between mt-6">
              <div class="flex items-center space-x-5">
                <div class="md:flex items-center">
                  <.live_file_input upload={@uploads.attachments} x-ref="file_input" class="sr-only" />
                  <button
                    type="button"
                    x-data
                    x-on:click={"document.getElementById('#{@uploads.attachments.ref}').click()"}
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
