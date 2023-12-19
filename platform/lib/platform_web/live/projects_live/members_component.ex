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
     |> assign(
       :memberships,
       Projects.get_project_memberships(assigns.project)
       |> Enum.sort_by(& &1.user.username)
     )
     |> assign(:changeset, nil)
     |> assign(:editing, nil)
     |> assign_can_remove_self()}
  end

  def assign_changeset(socket, changeset) do
    socket
    |> assign(:changeset, changeset)
    |> assign(:form, if(is_nil(changeset), do: nil, else: changeset |> to_form()))
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

    if socket.assigns.current_user.username == username do
      {:noreply,
       socket
       |> redirect(to: "/")
       |> put_flash(:info, "You have successfully removed yourself from the project.")}
    else
      {:noreply,
       socket
       |> assign(
         :memberships,
         Projects.get_project_memberships(socket.assigns.project)
         |> Enum.sort_by(& &1.user.username)
       )
       |> assign_can_remove_self()}
    end
  end

  def handle_event("edit_member", %{"username" => username}, socket) do
    if not can_edit(socket) do
      raise PlatformWeb.Errors.Unauthorized, "You do not have permission to edit this project"
    end

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
    if not can_edit(socket) do
      raise PlatformWeb.Errors.Unauthorized, "You do not have permission to edit this project"
    end

    params = params |> Map.put("project_id", socket.assigns.project.id)
    cs = changeset(socket, params)

    if cs.valid? do
      result =
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

          {:noreply,
           socket
           |> assign_changeset(nil)
           |> assign(:editing, nil)
           |> assign(
             :memberships,
             Projects.get_project_memberships(socket.assigns.project)
             |> Enum.sort_by(& &1.user.username)
           )
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
    <div class="flex flex-col lg:flex-row gap-4 pt-8 w-full">
      <div class="mb-4 lg:w-[20rem] lg:mr-16">
        <p class="sec-head text-xl">Members</p>
        <p class="sec-subhead">
          View and manage the users who have access to the project.
        </p>
      </div>
      <section class="flex flex-col mb-8 grow">
        <% can_edit = Permissions.can_edit_project_members?(@current_user, @project) %>
        <div class="flow-root">
          <div class="pb-4">
            <div class="inline-block min-w-full">
              <%= if Enum.empty?(@memberships) do %>
                <div class="text-sm text-gray-500">
                  This project has no members.
                </div>
              <% else %>
                <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8 grow">
                  <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
                    <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
                      <table class="min-w-full divide-y divide-gray-300">
                        <thead class="bg-gray-50">
                          <tr>
                            <th
                              scope="col"
                              class="pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6 py-4"
                            >
                              User
                            </th>
                            <th
                              scope="col"
                              class="px-3 text-left text-sm font-semibold text-gray-900 py-4"
                            >
                              Role
                            </th>
                            <th
                              scope="col"
                              class="relative pl-3 pr-4 sm:pr-2 text-right lg:whitespace-nowrap"
                            >
                              <%= if @can_remove_self do %>
                                <button
                                  type="button"
                                  class="button ~critical @high my-2"
                                  phx-click="leave_project"
                                  data-confirm="Are you sure you want to leave this project? To rejoin it, you will need to be invited again."
                                  phx-target={@myself}
                                >
                                  Leave Project
                                </button>
                              <% end %>
                              <span class="sr-only">Manage</span>
                            </th>
                          </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200 bg-white">
                          <%= for membership <- @memberships do %>
                            <tr class="py-2">
                              <td class="pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                                <.user_text
                                  user={membership.user}
                                  icon={true}
                                  profile_photo_class="h-8 w-8"
                                />
                              </td>
                              <td class="px-3 text-sm text-gray-500">
                                <div>
                                  <%= case membership.role do %>
                                    <% :owner -> %>
                                      <span class="chip ~critical @high">Owner</span>
                                    <% :manager -> %>
                                      <span class="chip ~critical">Manager</span>
                                    <% :editor -> %>
                                      <span class="chip ~info">Editor</span>
                                    <% :viewer -> %>
                                      <span class="chip ~neutral">Viewer</span>
                                  <% end %>
                                </div>
                              </td>
                              <td class="relative pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                                <%= if can_edit do %>
                                  <%= if not (membership.role == :owner and Enum.filter(@memberships, & &1.role == :owner) |> length() == 1) do %>
                                    <button
                                      phx-target={@myself}
                                      class="text-button text-neutral-600 mr-2"
                                      phx-click="delete_member"
                                      phx-value-username={membership.user.username}
                                      data-confirm={"Are you sure that you want to remove #{membership.user.username} from #{@project.name}?"}
                                      data-tooltip={"Remove #{membership.user.username}"}
                                    >
                                      <Heroicons.minus_circle mini class="h-5 w-5" />
                                      <span class="sr-only">
                                        Remove <%= membership.user.username %>
                                      </span>
                                    </button>
                                  <% end %>
                                  <button
                                    phx-target={@myself}
                                    class="text-button text-neutral-600"
                                    phx-click="edit_member"
                                    phx-value-username={membership.user.username}
                                    data-tooltip={"Change permissions for #{membership.user.username}"}
                                  >
                                    <Heroicons.cog_6_tooth mini class="h-5 w-5" />
                                    <span class="sr-only">Edit <%= membership.user.username %></span>
                                  </button>
                                <% end %>
                              </td>
                            </tr>
                          <% end %>
                          <!-- More people... -->
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </section>
      <%= if not is_nil(@changeset) and can_edit do %>
        <.modal target={} close_confirmation="Your changes will be lost. Are you sure?">
          <div class="mb-8">
            <p class="sec-head">
              Edit role
            </p>
          </div>
          <.form
            for={@form}
            class="flex flex-col space-y-8 phx-form"
            phx-change="validate"
            phx-submit="save"
            phx-target={@myself}
          >
            <div class="rounded-lg border shadow-sm text-sm">
              <%= hidden_input(@form, :username, value: @editing) %>
              <.user_card user={Enum.find(@memberships, &(&1.user.username == @editing)).user} />
            </div>

            <div>
              <%= label(
                @form,
                :role,
                "Role"
              ) %>
              <div class="phx-form" id="member-role-select" phx-update="ignore">
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
                "Save",
                phx_disable_with: "Saving...",
                class: "button ~urge @high"
              ) %>
            </div>
          </.form>
        </.modal>
      <% end %>
    </div>
    """
  end
end
