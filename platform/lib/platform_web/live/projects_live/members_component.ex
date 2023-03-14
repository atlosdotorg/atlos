defmodule PlatformWeb.ProjectsLive.MembersComponent do
  use PlatformWeb, :live_component

  alias Platform.Projects.ProjectMembership
  alias Platform.Auditor
  alias Platform.Projects
  alias Platform.Permissions

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:memberships, Projects.get_project_memberships(assigns.project))
     |> assign(:changeset, nil)
     |> assign(:editing, nil)
     |> assign_can_remove_self()}
  end

  def assign_changeset(socket, changeset) do
    socket
    |> assign(:changeset, changeset)
    |> assign(:form, if(not is_nil(changeset), do: changeset |> to_form(), else: nil))
  end

  def assign_can_remove_self(socket) do
    own_membership =
      Enum.find(socket.assigns.memberships, fn m ->
        m.user_id == socket.assigns.current_user.id
      end)

    total_owners =
      Enum.filter(socket.assigns.memberships, fn m -> m.role == :owner end) |> length()

    socket
    |> assign(:can_remove_self, total_owners > 1 or own_membership.role != :owner)
  end

  def changeset(socket, params \\ %{}) do
    params = params |> Map.put("project_id", socket.assigns.project.id)

    if not can_edit(socket) do
      raise PlatformWeb.Errors.Unauthorized, "You do not have permission to edit this project"
    end

    case socket.assigns.editing do
      nil ->
        Projects.change_project_membership(
          %ProjectMembership{},
          params,
          all_memberships: socket.assigns.memberships
        )

      username ->
        Projects.change_project_membership(
          Enum.find(socket.assigns.memberships, fn m ->
            String.downcase(m.user.username) == String.downcase(username)
          end),
          params,
          all_memberships: socket.assigns.memberships
        )
    end
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> assign_changeset(nil) |> assign(:editing, nil)}
  end

  def handle_event("add_member", _params, socket) do
    {:noreply,
     socket
     |> assign_changeset(changeset(socket))
     |> assign(:editing, nil)}
  end

  def handle_event("delete_member", %{"username" => username}, socket) do
    if not can_edit(socket) do
      raise PlatformWeb.Errors.Unauthorized, "You do not have permission to edit this project"
    end

    # Don't allow the last owner to be removed
    owners = socket.assigns.memberships |> Enum.filter(&(&1.role == :owner))

    if length(owners) == 1 and hd(owners).user.username == username do
      raise PlatformWeb.Errors.Unauthorized, "You cannot remove the last owner"
    end

    membership =
      Enum.find(socket.assigns.memberships, fn m ->
        String.downcase(m.user.username) == String.downcase(username)
      end)

    Projects.delete_project_membership(membership)

    Auditor.log(
      :project_membership_changed,
      socket.assigns.current_user,
      %{
        project_id: socket.assigns.project.id,
        user_id: membership.user_id,
        project_membership_id: membership.id
      }
    )

    {:noreply,
     socket
     |> assign(:memberships, Projects.get_project_memberships(socket.assigns.project))
     |> assign_can_remove_self()}
  end

  def handle_event("edit_member", %{"username" => username}, socket) do
    socket =
      socket
      |> assign(:editing, username)

    {:noreply,
     socket
     |> assign_changeset(changeset(socket))}
  end

  def handle_event("leave_project", _params, socket) do
    if not socket.assigns.can_remove_self do
      raise PlatformWeb.Errors.Unauthorized, "You cannot remove yourself from this project"
    end

    # Regardless of their ability to edit the project, they should be able to leave
    membership =
      Projects.get_project_membership_by_user_and_project(
        socket.assigns.current_user,
        socket.assigns.project
      )

    {:ok, _} = Projects.delete_project_membership(membership)

    Auditor.log(
      :project_left,
      %{user_id: socket.assigns.current_user.id, project_id: socket.assigns.project.id},
      socket
    )

    {:noreply,
     socket
     |> redirect(to: "/")
     |> put_flash(:info, "You have successfully removed yourself from the project.")}
  end

  def handle_event("validate", %{"project_membership" => params}, socket) do
    cs =
      changeset(socket, params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign_changeset(cs)}
  end

  def handle_event("save", %{"project_membership" => params}, socket) do
    cs = changeset(socket, params)

    is_creation = is_nil(socket.assigns.editing)

    if cs.valid? do
      params = params |> Map.put("project_id", socket.assigns.project.id)

      result =
        if is_creation,
          do: Projects.create_project_membership(params),
          else:
            Projects.update_project_membership(
              Enum.find(socket.assigns.memberships, fn m ->
                String.downcase(m.user.username) ==
                  String.downcase(Ecto.Changeset.get_field(cs, :username))
              end),
              params,
              all_memberships: socket.assigns.memberships
            )

      case result do
        {:ok, membership} ->
          Auditor.log(
            :project_membership_changed,
            socket.assigns.current_user,
            %{
              project_id: socket.assigns.project.id,
              user_id: membership.user_id,
              project_membership_id: membership.id
            }
          )

          if is_creation do
            # Send a notification to the invited user
            Platform.Notifications.send_message_notification_to_user(
              Platform.Accounts.get_user!(membership.user_id),
              "You have been added to the project [#{socket.assigns.project.name |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()}](/projects/#{socket.assigns.project.id}) by [#{socket.assigns.current_user.username}](/profile/#{socket.assigns.current_user.username})."
            )
          end

          {:noreply,
           socket
           |> assign_changeset(nil)
           |> assign(:editing, nil)
           |> assign(:memberships, Projects.get_project_memberships(socket.assigns.project))
           |> assign_can_remove_self()}

        {:error, changeset} ->
          {:noreply, socket |> assign_changeset(changeset |> Map.put(:action, :validate))}
      end
    else
      {:noreply, socket |> assign_changeset(cs |> Map.put(:action, :validate))}
    end
  end

  def can_edit(socket) do
    Permissions.can_edit_project_members?(socket.assigns.current_user, socket.assigns.project)
  end

  def render(assigns) do
    ~H"""
    <section>
      <% can_edit = Permissions.can_edit_project_members?(@current_user, @project) %>
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="sec-head">Members</h1>
          <p class="sec-subhead">
            View and manage the users who have access to the project.
          </p>
        </div>
        <div>
          <div class="mt-4 sm:mt-0 sm:ml-16 flex gap-4">
            <%= if can_edit do %>
              <button
                type="button"
                class="button ~urge @high"
                phx-click="add_member"
                phx-target={@myself}
              >
                Add Member
              </button>
            <% end %>
            <%= if @can_remove_self do %>
              <button
                type="button"
                class="button ~critical @high"
                phx-click="leave_project"
                data-confirm="Are you sure you want to leave this project? To rejoin it, you will need to be invited again."
                phx-target={@myself}
              >
                Leave Project
              </button>
            <% end %>
          </div>
        </div>
      </div>
      <div class="mt-8 flow-root">
        <div class="pb-4">
          <div class="inline-block min-w-full">
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <%= for membership <- @memberships do %>
                <article class="text-sm rounded-lg shadow-sm border flex flex-col overflow-hidden">
                  <div class="bg-white p-2 grow">
                    <.user_card user={membership.user} />
                  </div>
                  <div class="flex justify-between items-center bg-white border-t p-4">
                    <div>
                      <%= case membership.role do %>
                        <% :owner -> %>
                          <span class="chip ~critical @high">Owner</span>
                        <% :manager -> %>
                          <span class="chip ~critical @low">Manager</span>
                        <% :editor -> %>
                          <span class="chip ~info @high">Editor</span>
                        <% :viewer -> %>
                          <span class="chip ~neutral @high">Viewer</span>
                      <% end %>
                    </div>
                    <div>
                      <%= if can_edit do %>
                        <button
                          phx-target={@myself}
                          class="text-button"
                          phx-click="edit_member"
                          phx-value-username={membership.user.username}
                        >
                          Edit<span class="sr-only">, <%= membership.user.username %></span>
                        </button>
                        <%= if not (membership.role == :owner and Enum.filter(@memberships, & &1.role == :owner) |> length() == 1) do %>
                          <button
                            phx-target={@myself}
                            class="text-button text-critical-600 ml-2"
                            phx-click="delete_member"
                            phx-value-username={membership.user.username}
                            data-confirm={"Are you sure that you want to remove #{membership.user.username} from #{@project.name}?"}
                          >
                            Remove<span class="sr-only">, <%= membership.user.username %></span>
                          </button>
                        <% end %>
                      <% end %>
                    </div>
                  </div>
                </article>
              <% end %>
              <%= if Enum.empty?(@memberships) do %>
                <div class="text-sm text-gray-500">
                  No members found.
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
      <%= if not is_nil(@changeset) and can_edit do %>
        <.modal target={} close_confirmation="Your changes will be lost. Are you sure?">
          <div class="mb-8">
            <p class="sec-head">
              <%= if is_nil(@editing) do %>
                Add member
              <% else %>
                Edit role
              <% end %>
            </p>
          </div>
          <.form
            for={@form}
            class="flex flex-col space-y-8 phx-form"
            phx-change="validate"
            phx-submit="save"
            phx-target={@myself}
          >
            <%= if is_nil(@editing) do %>
              <div>
                <%= label(
                  @form,
                  :username,
                  "Username"
                ) %>
                <%= text_input(
                  @form,
                  :username,
                  placeholder: "The username of the user you want to add",
                  phx_debounce: 1000
                ) %>
                <%= error_tag(@form, :username) %>
              </div>
            <% else %>
              <div class="rounded-lg border shadow-sm text-sm">
                <%= hidden_input(@form, :username, value: @editing) %>
                <.user_card user={Enum.find(@memberships, &(&1.user.username == @editing)).user} />
              </div>
            <% end %>

            <div>
              <%= label(
                @form,
                :role,
                "Role"
              ) %>
              <div id="role-select" phx-update="ignore">
                <%= select(
                  @form,
                  :role,
                  [
                    {"Viewer", "viewer"},
                    {"Editor", "editor"},
                    {"Manager", "manager"},
                    {"Owner", "owner"}
                  ],
                  "data-descriptions":
                    Jason.encode!(%{
                      "viewer" => "Can view and comment, but not edit or create",
                      "editor" => "Can view, comment, and edit, but not mark as complete",
                      "manager" =>
                        "Can view, comment, edit, mark as complete, and edit completed incidents",
                      "owner" =>
                        "Everything managers can do, plus add and remove members to the project"
                    })
                ) %>
              </div>
              <%= error_tag(@form, :role) %>
            </div>
            <div>
              <%= submit(
                if(@editing, do: "Save", else: "Add Member"),
                phx_disable_with: "Saving...",
                class: "button ~urge @high"
              ) %>
            </div>
          </.form>
        </.modal>
      <% end %>
    </section>
    """
  end
end
