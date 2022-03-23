defmodule PlatformWeb.SettingsLive.ProfileComponent do
  use PlatformWeb, :live_component
  alias Platform.Accounts
  alias Platform.Utils

  def update(%{current_user: current_user} = assigns, socket) do
    changeset = Accounts.change_user_profile(current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:profile_photo_display, current_user.profile_photo_file)
     |> allow_upload(:profile_photo_file,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 1,
       max_file_size: 1_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.current_user
      |> Accounts.change_user_profile(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.update_user_profile(socket.assigns.current_user, user_params) do
      {:ok, user} ->
        send(self(), :update_successful)
        {:noreply,
         socket
         |> assign(:current_user, user)
         |> assign(:changeset, Accounts.change_user_profile(user))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def update_changeset(%{assigns: %{changeset: changeset}} = socket, key, value) do
    socket |> assign(:changeset, Ecto.Changeset.put_change(changeset, key, value))
  end

  defp handle_progress(:profile_photo_file, entry, socket) do
    if entry.done? do
      # TODO: add a context function to upload to persistent storage
      path = consume_uploaded_entry(socket, entry, &upload_static_file(&1, socket))

      {:noreply,
       socket
       |> update_changeset(:profile_photo_file, path)
       |> assign(:profile_photo_display, path)}
    else
      {:noreply, socket}
    end
  end

  defp upload_static_file(%{path: path}, socket) do
    Utils.upload_ugc_file(path, socket)
  end

  defp has_changes(changeset) do
    changeset.changes != %{}
  end

  defp friendly_error(:too_large), do: "This file is too large; the maximum size is 1 megabyte."
  defp friendly_error(:not_accepted), do: "Please upload a .PNG, .JPG, or .JPEG file."

  def render(assigns) do
    ~H"""
    <article>
      <.form
        let={f}
        for={@changeset}
        id="profile-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="phx-form"
      >
        <div class="space-y-6">
          <div>
            <label>Username</label>
            <input type="text" class="my-1" disabled value={@current_user.username} />
            <p class="support">If you would like to change your username, please contact us.</p>
          </div>
          <div>
            <%= label f, :profile_photo_file, "Profile Photo" %>
            <div class="mt-1 flex items-center" phx-drop-target={@uploads.profile_photo_file.ref}>
              <div class="h-12 w-12 rounded-full overflow-hidden">
                <% photo = if byte_size(@profile_photo_display) > 0, do: @profile_photo_display, else: Routes.static_path(@socket, "/images/default_profile.jpg") %>
                <img class="w-full h-full" src={photo} />
              </div>
              <div>
              <label for="profile_photo_file">
                <button class="button ~neutral ml-4" type="button" onclick="document.querySelector('input[name=\'profile_photo_file\']').click()">Change</button>
                <%= live_file_input @uploads.profile_photo_file, class: "sr-only" %>
              </label>
              <%= hidden_input f, :profile_photo_file %>
              </div>
            </div>
            <%= for entry <- @uploads.profile_photo_file.entries do %>
              <%= if entry.progress < 100 and entry.progress > 0 do %>
                <progress value={entry.progress} max="100" class="progress mt-2"> <%= entry.progress %>% </progress>
              <% end %>
              <%= for err <- upload_errors(@uploads.profile_photo_file, entry) do %>
                <p class="invalid-feedback mt-2"><%= friendly_error(err) %></p>
              <% end %>
            <% end %>
            <%= error_tag f, :profile_photo_file %>
          </div>

          <div>
            <%= label f, :bio %>
            <div class="mt-1">
              <%= textarea f, :bio, rows: 4 %>
            </div>
            <%= error_tag f, :bio %>
          </div>

          <%= submit "Save", phx_disable_with: "Saving...", class: "button ~urge @high", disabled: !has_changes(@changeset) %>
        </div>
      </.form>
    </article>
    """
  end
end
