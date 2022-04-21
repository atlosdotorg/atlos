defmodule PlatformWeb.ProfilesLive.EditComponent do
  use PlatformWeb, :live_component
  alias Platform.Accounts

  def update(assigns, socket) do
    if Accounts.is_admin(assigns.current_user) do
      {:ok,
       socket
       |> assign(assigns)
       |> assign_user()
       |> assign_changeset()}
    else
      socket
      |> push_patch(to: Routes.profiles_show_path(socket, :show, socket.assigns.media.slug))
    end
  end

  defp assign_user(socket) do
    user = Accounts.get_user_by_username(socket.assigns.username)
    socket |> assign(:user, user)
  end

  defp assign_changeset(socket, attrs \\ %{}) do
    socket
    |> assign(
      :changeset,
      Accounts.change_user_admin(socket.assigns.user, attrs)
    )
  end

  def close(socket) do
    socket |> push_patch(to: Routes.profiles_show_path(socket, :show, socket.assigns.username))
  end

  defp hydrate_params(params) do
    # TODO: Is there a Phoenix utility that will do this for us?
    params
    |> Map.put_new("restrictions", [])
    |> Map.put_new("roles", [])
    |> Map.put_new("bio", "")
  end

  def handle_event("close_modal", _, socket) do
    {:noreply, close(socket)}
  end

  def handle_event("save", %{"user" => params} = _input, socket) do
    # Just to be sure, we check authorization again. It would be nice if this were
    # done more centrally.
    if not Accounts.is_admin(socket.assigns.current_user) do
      raise "no permission"
    end

    case Accounts.update_user_admin(
           socket.assigns.user,
           params |> hydrate_params()
         ) do
      {:ok, _media} ->
        {:noreply, socket |> put_flash(:info, "The access changes have been saved.") |> close()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("validate", %{"user" => params} = _input, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user_admin(params |> hydrate_params())
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def render(assigns) do
    confirm_prompt = "This will discard your changes without saving. Are you sure?"

    ~H"""
    <article>
      <.modal target={@myself} close_confirmation={confirm_prompt}>
        <h3 class="sec-head">Editing <%= @user.username %></h3>
        <p class="sec-subhead">These changes will affect this user's account.</p>
        <hr class="h-8 sep" />
        <.form
          let={f}
          for={@changeset}
          id={"#{@user.username}-access"}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
          class="phx-form"
        >
          <div class="space-y-6">
            <div>
              <%= label(f, :roles, "Roles") %>
              <div phx-update="ignore" id="ignore-user-roles">
                <%= multiple_select(f, :roles, [:coordinator, :trusted, :admin],
                  id: "user-roles-input"
                ) %>
              </div>
              <%= error_tag(f, :roles) %>
            </div>
            <div>
              <%= label(f, :restrictions, "Restrictions") %>
              <div phx-update="ignore" id="ignore-user-restrictions">
                <%= multiple_select(f, :restrictions, [:banned, :muted], id: "user-restrictions-input") %>
              </div>
              <%= error_tag(f, :restrictions) %>
            </div>
            <div>
              <%= label(f, :bio, "Bio") %>
              <%= textarea(f, :bio) %>
              <%= error_tag(f, :bio) %>
            </div>
            <div>
              <%= label(f, :flair, "Flair") %>
              <%= text_input(f, :flair) %>
              <%= error_tag(f, :flair) %>
            </div>
            <div class="flex md:justify-between">
              <%= submit("Save",
                phx_disable_with: "Saving...",
                class: "button ~urge @high"
              ) %>
              <button
                phx-click="close_modal"
                phx-target={@myself}
                data-confirm={confirm_prompt}
                type="button"
                class="base-button"
              >
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
