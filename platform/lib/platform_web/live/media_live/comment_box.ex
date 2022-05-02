defmodule PlatformWeb.MediaLive.CommentBox do
  use PlatformWeb, :live_component
  alias Platform.Accounts
  alias Platform.Updates

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:disabled, fn -> false end)
     |> assign_new(:id, fn -> Platform.Utils.generate_random_sequence(10) end)
     |> assign_changeset()}
  end

  defp assign_changeset(socket) do
    socket
    |> assign(
      :changeset,
      Updates.change_from_comment(socket.assigns.media, socket.assigns.current_user)
    )
  end

  def handle_event("save", %{"update" => params} = _input, socket) do
    changeset =
      Updates.change_from_comment(socket.assigns.media, socket.assigns.current_user, params)

    case Updates.create_update_from_changeset(changeset) do
      {:ok, _update} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your comment has been posted.")
         |> assign_changeset()
         |> push_patch(to: Routes.media_show_path(socket, :show, socket.assigns.media.slug))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("validate", %{"update" => params} = _input, socket) do
    changeset =
      Updates.change_from_comment(socket.assigns.media, socket.assigns.current_user, params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def render(assigns) do
    ~H"""
    <section class="relative bg-white pt-2 mt-2">
      <.form let={f} for={@changeset} phx-target={@myself} phx-change="validate" phx-submit="save">
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
                  rows: 3,
                  placeholder:
                    if(@disabled, do: "Commenting has been disabled", else: "Add your comment..."),
                  class: "block w-full py-3 border-0 resize-none focus:ring-0 sm:text-sm",
                  required: true,
                  disabled: @disabled,
                  id: "input-#{@id}"
                ) %>
                <!-- Spacer element to match the height of the toolbar -->
                <div class="py-2" aria-hidden="true">
                  <!-- Matches height of button in toolbar (1px border + 36px content height) -->
                  <div class="py-px">
                    <div class="h-9"></div>
                  </div>
                </div>
              </div>

              <div class="absolute bottom-0 inset-x-0 pl-3 pr-2 py-2 flex justify-between">
                <div class="flex items-center space-x-5">
                  <div class="flex items-center">
                    <button
                      type="button"
                      class="-m-2.5 w-10 h-10 rounded-full flex items-center justify-center text-gray-400 hover:text-gray-500"
                    >
                      <!-- Heroicon name: solid/paper-clip -->
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
