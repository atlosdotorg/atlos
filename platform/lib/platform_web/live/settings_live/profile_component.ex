defmodule PlatformWeb.SettingsLive.ProfileComponent do
  use PlatformWeb, :live_component
  alias Platform.Accounts

  def update(%{current_user: current_user} = assigns, socket) do
    changeset = Accounts.change_user_profile(current_user)

    {:ok, socket |> assign(assigns) |> assign(:changeset, changeset) |> allow_upload(:profile_photo_file, accept: ~w(.jpg .jpeg .png), max_entries: 1, max_file_size: 1_000_000, auto_upload: true, progress: &handle_progress/3)}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = socket.assigns.current_user |> Accounts.change_user_profile(user_params) |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.update_user_profile(socket.assigns.current_user, user_params) do
      {:ok, _user} ->
        {:noreply, socket |> put_flash(:info, "Your profile has been updated")}
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def update_changeset(%{assigns: %{changeset: changeset}} = socket, key, value) do
    socket |> assign(:changeset, Ecto.Changeset.put_change(changeset, key, value))
  end

  defp handle_progress(:profile_photo_file, entry, socket) do
    IO.puts("progress")
    if entry.done? do
      path = consume_uploaded_entry(socket, entry, &upload_static_file(&1, socket)) # TODO: add a context function to upload to persistent storage

      {:noreply,
       socket
       |> update_changeset(:profile_photo_file, path)}
    else
      {:noreply, socket}
    end
  end

  defp upload_static_file(%{path: path}, socket) do
    dest = Path.join("priv/static/images", Path.basename(path))
    File.cp!(path, dest)
    {:ok, Routes.static_path(socket, "/images/#{Path.basename(dest)}")}
  end

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
            <%= label f, :profile_photo_file, "Profile Photo" %>
            <div class="mt-1 flex items-center" phx-drop-target={@uploads.profile_photo_file.ref}>
              <span class="inline-block h-12 w-12 rounded-full overflow-hidden bg-gray-100">
                <img src={@changeset.data.profile_photo_file} />
                <%= hidden_input f, :profile_photo_file %>
              </span>
              <%= live_file_input @uploads.profile_photo_file %>
              <%= error_tag f, :profile_photo_file %>
            </div>
          </div>

          <div>
            <%= label f, :bio %>
            <div class="mt-1">
              <%= textarea f, :bio %>
            </div>
            <%= error_tag f, :bio %>
          </div>

          <%= submit "Save", phx_disable_with: "Saving...", class: "button ~urge @high" %>
        </div>
      </.form>
    </article>
    """
  end
end
