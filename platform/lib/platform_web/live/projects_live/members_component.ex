defmodule PlatformWeb.ProjectsLive.MembersComponent do
  use PlatformWeb, :live_component

  alias Platform.Projects.ProjectMembership
  alias Platform.Auditor
  alias Platform.Projects

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:memberships, Projects.get_project_memberships(assigns.project))
     |> assign(:changeset, nil)
     |> assign(:editing, nil)}
  end

  def assign_changeset(socket, changeset) do
    socket
    |> assign(:changeset, changeset)
    |> assign(:form, if(not is_nil(changeset), do: changeset |> to_form(), else: nil))
  end

  def changeset(socket, params \\ %{}) do
    params = params |> Map.put("project_id", socket.assigns.project.id)

    case socket.assigns.editing do
      nil ->
        Projects.change_project_membership(
          %ProjectMembership{},
          params
        )

      username ->
        Projects.change_project_membership(
          Enum.find(socket.assigns.memberships, fn m ->
            String.downcase(m.user.username) == String.downcase(username)
          end),
          params
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

  def handle_event("edit_member", %{"username" => username}, socket) do
    socket =
      socket
      |> assign(:editing, username)

    {:noreply,
     socket
     |> assign_changeset(changeset(socket))}
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

    if cs.valid? do
      params = params |> Map.put("project_id", socket.assigns.project.id)

      result =
        if is_nil(socket.assigns.editing),
          do: Projects.create_project_membership(params),
          else:
            Projects.update_project_membership(
              Enum.find(socket.assigns.memberships, fn m ->
                String.downcase(m.user.username) ==
                  String.downcase(Ecto.Changeset.get_field(cs, :username))
              end),
              params
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
           |> assign(:memberships, Projects.get_project_memberships(socket.assigns.project))}

        {:error, changeset} ->
          {:noreply, socket |> assign_changeset(changeset |> Map.put(:action, :validate))}
      end
    else
      {:noreply, socket |> assign_changeset(cs |> Map.put(:action, :validate))}
    end
  end

  def render(assigns) do
    ~H"""
    <section>
      <div class="sm:flex sm:items-center">
        <div class="sm:flex-auto">
          <h1 class="sec-head">Members</h1>
          <p class="sec-subhead">
            View and manage the users who have access to the project.
          </p>
        </div>
        <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <button type="button" class="button ~urge @high" phx-click="add_member" phx-target={@myself}>
            Add member
          </button>
        </div>
      </div>
      <div class="mt-8 flow-root">
        <div class="pb-4">
          <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8 rounded-lg bg-white border p-2 shadow-sm">
            <table class="min-w-full divide-y divide-gray-300">
              <thead>
                <tr>
                  <th
                    scope="col"
                    class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-0"
                  >
                    User
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                    MFA
                  </th>
                  <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                    Role
                  </th>
                  <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-0">
                    <span class="sr-only">Edit</span>
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 bg-white">
                <%= for membership <- @memberships do %>
                  <tr>
                    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm sm:pl-0">
                      <div class="flex items-center">
                        <div class="h-10 w-10 flex-shrink-0">
                          <img
                            class="h-10 w-10 rounded-full"
                            src={Platform.Accounts.get_profile_photo_path(membership.user)}
                            alt={"Profile photo of " <> membership.user.username}
                          />
                        </div>
                        <div class="ml-4">
                          <div class="font-medium text-gray-900">
                            <.user_text user={membership.user} />
                          </div>
                        </div>
                      </div>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <%= if membership.user.has_mfa do %>
                        <span class="chip ~positive">Enabled</span>
                      <% else %>
                        <span class="chip ~critical">Disabled</span>
                      <% end %>
                    </td>
                    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                      <%= case membership.role do %>
                        <% :owner -> %>
                          Owner
                        <% :admin -> %>
                          Admin
                        <% :member -> %>
                          Member
                        <% :viewer -> %>
                          Viewer
                      <% end %>
                    </td>
                    <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-0">
                      <button
                        phx-target={@myself}
                        class="text-button"
                        phx-click="edit_member"
                        phx-value-username={membership.user.username}
                      >
                        Edit<span class="sr-only">, <%= membership.user.username %></span>
                      </button>
                    </td>
                  </tr>
                <% end %>
                <%= if Enum.empty?(@memberships) do %>
                  <tr>
                    <td class="py-4 text-sm text-gray-500" colspan="4">
                      No members found.
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <%= if @changeset do %>
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
              <div class="rounded-lg border shadow-sm">
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
                    {"Owner", "owner"},
                    {"Manager", "manager"},
                    {"Editor", "editor"},
                    {"Viewer", "viewer"}
                  ]
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
