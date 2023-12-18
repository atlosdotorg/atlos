defmodule PlatformWeb.ProjectsLive.InvitesComponent do
  use PlatformWeb, :live_component

  alias Platform.Projects.ProjectMembership
  alias Platform.Auditor
  alias Platform.Projects
  alias Platform.Invites
  alias Platform.Permissions

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_invites()

    {:ok,
     socket
     |> assign(:can_edit, can_edit(socket))
     |> assign(:changeset, nil)}
  end

  def assign_invites(socket) do
    invites =
      Invites.get_invites_by_project(socket.assigns.project)
      |> Enum.filter(&Invites.is_invite_active/1)
      |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})

    assign(socket, :invites, invites)
  end

  def assign_changeset(socket, changeset) do
    socket
    |> assign(:changeset, changeset)
    |> assign(:form, if(is_nil(changeset), do: nil, else: changeset |> to_form()))
  end

  def changeset(socket, params \\ %{}) do
    params =
      params
      |> Map.put("project_id", socket.assigns.project.id)
      |> Map.put("owner_id", socket.assigns.current_user.id)

    if not can_edit(socket) do
      raise PlatformWeb.Errors.Unauthorized, "You do not have permission to edit this project"
    end

    Invites.change_invite(
      %Invites.Invite{},
      params
    )
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> assign_changeset(nil)}
  end

  def handle_event("deactivate_invite", %{"id" => invite_id}, socket) do
    if not can_edit(socket) do
      raise PlatformWeb.Errors.Unauthorized, "You do not have permission to edit this project"
    end

    invite =
      Enum.find(socket.assigns.invites, fn m ->
        m.id == invite_id
      end)

    {:ok, invite} = Invites.update_invite(invite, %{active: false})

    Auditor.log(
      :invite_deactivated,
      socket.assigns.current_user,
      %{
        invite_id: invite.id,
        user_id: socket.assigns.current_user.id
      }
    )

    {:noreply,
     socket
     |> assign_invites()
     |> put_flash(:info, "Deactivated the invite. It can no longer be used to join the project.")}
  end

  def handle_event("create_invite", %{}, socket) do
    if not can_edit(socket) do
      raise PlatformWeb.Errors.Unauthorized, "You do not have permission to edit this project"
    end

    {:noreply,
     socket
     |> assign_changeset(changeset(socket))}
  end

  def handle_event("validate", %{"invite" => params}, socket) do
    cs =
      changeset(socket, params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign_changeset(cs)}
  end

  def handle_event("save", %{"invite" => params}, socket) do
    if not can_edit(socket) do
      raise PlatformWeb.Errors.Unauthorized, "You do not have permission to edit this project"
    end

    params =
      params
      |> Map.put("project_id", socket.assigns.project.id)
      |> Map.put("owner_id", socket.assigns.current_user.id)

    cs = changeset(socket, params)

    if cs.valid? do
      result =
        Invites.create_invite(params)

      case result do
        {:ok, invite} ->
          Auditor.log(
            :invite_created,
            socket.assigns.current_user,
            %{
              invite_id: invite.id,
              project_id: socket.assigns.project.id
            }
          )

          {:noreply,
           socket
           |> assign_changeset(nil)
           |> assign_invites()}

        {:error, changeset} ->
          {:noreply, socket |> assign_changeset(changeset |> Map.put(:action, :validate))}
      end
    else
      {:noreply, socket |> assign_changeset(cs |> Map.put(:action, :validate))}
    end
  end

  def can_edit(socket) do
    Permissions.can_edit_project_members?(socket.assigns.current_user, socket.assigns.project) and
      Permissions.can_create_invite?(socket.assigns.current_user)
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col md:flex-row gap-4 pt-8 w-full">
      <div class="mb-4 md:w-[20rem] md:mr-16">
        <p class="sec-head text-xl">Invites</p>
        <p class="sec-subhead">
          View and manage invitations to this project.
        </p>
      </div>
      <section class="flex flex-col mb-8 grow">
        <div class="flow-root">
          <div class="pb-4">
            <div class="inline-block min-w-full">
              <%= if Enum.empty?(@invites) do %>
                <div class="text-center w-full bg-white border rounded-lg shadow py-8 px-8">
                  <Heroicons.user_plus class="mx-auto h-8 w-8 text-gray-400" />
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No invites</h3>
                  <%= if @can_edit do %>
                    <p class="mt-1 text-sm text-gray-500">
                      Add users to this project by creating an invite.
                    </p>
                    <div class="mt-6">
                      <button
                        type="button"
                        class="button ~urge @high"
                        phx-target={@myself}
                        phx-click="create_invite"
                      >
                        New Invite
                      </button>
                    </div>
                  <% end %>
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
                              Link
                            </th>
                            <th
                              scope="col"
                              class="pr-3 text-left text-sm font-semibold text-gray-900 py-4"
                            >
                              Type
                            </th>
                            <th
                              scope="col"
                              class="pr-3 text-left text-sm font-semibold text-gray-900 py-4"
                            >
                              Created By
                            </th>
                            <th
                              scope="col"
                              class="pr-3 text-left text-sm font-semibold text-gray-900 py-4"
                            >
                              Used By
                            </th>
                            <th
                              scope="col"
                              class="pr-3 text-left text-sm font-semibold text-gray-900 py-4"
                              data-tooltip="Users who use this invite will be added to the project with this role."
                            >
                              Role
                            </th>
                            <th
                              scope="col"
                              class="relative pl-3 pr-4 sm:pr-2 text-right lg:whitespace-nowrap"
                            >
                              <%= if @can_edit do %>
                                <button
                                  type="button"
                                  class="button ~urge @high my-2"
                                  phx-click="create_invite"
                                  phx-target={@myself}
                                >
                                  Create Invite
                                </button>
                              <% end %>
                              <span class="sr-only">Manage</span>
                            </th>
                          </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200 bg-white">
                          <%= for invite <- @invites do %>
                            <tr class={
                              "py-2 " <>
                                if not Invites.is_invite_active(invite), do: "opacity-50", else: ""
                            }>
                              <td class="pl-4 sm:pl-6 pr-3 text-sm font-medium text-gray-900">
                                <%= invite.code %>
                              </td>
                              <td class="pr-3 text-sm text-gray-600">
                                <%= if invite.single_use do %>
                                  Single use
                                <% else %>
                                  Multi use
                                <% end %>
                                expiring <.rel_time time={invite.expires} />
                              </td>
                              <td class="pr-3 text-sm text-gray-600 -ml-2">
                                <.user_card user={invite.owner} profile_photo_class="h-6 w-6" />
                              </td>
                              <td class="pr-3 text-sm  text-gray-600">
                                <.user_stack
                                  :if={not Enum.empty?(invite.uses)}
                                  users={invite.uses |> Enum.map(& &1.user)}
                                />
                                <span :if={Enum.empty?(invite.uses)} class="text-gray-500">
                                  No one
                                </span>
                              </td>
                              <td class="pr-3 text-sm text-gray-500">
                                <div>
                                  <%= case invite.project_access_level do %>
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
                                <%= if @can_edit and Invites.is_invite_active(invite) do %>
                                  <button
                                    phx-target={@myself}
                                    class="text-button text-neutral-600 mr-2"
                                    phx-click="deactivate_invite"
                                    phx-value-id={invite.id}
                                    data-confirm="Are you sure that you want deactivate this invite code?"
                                    data-tooltip="Deactivate this invite code"
                                  >
                                    <Heroicons.minus_circle mini class="h-5 w-5" />
                                    <span class="sr-only">
                                      Deactivate this invite
                                    </span>
                                  </button>
                                <% end %>
                              </td>
                            </tr>
                          <% end %>
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
      <%= if not is_nil(@changeset) and @can_edit do %>
        <.modal target={} close_confirmation="Your changes will be lost. Are you sure?">
          <div class="mb-8">
            <p class="sec-head">
              Invite others to <%= @project.name %>
            </p>
          </div>
          <.form
            for={@form}
            class="flex flex-col space-y-8 phx-form"
            phx-change="validate"
            phx-submit="save"
            phx-target={@myself}
          >
            <div class="text-sm text-urge-800 flex flex-col gap-4 bg-urge-50 border border-urge-600 p-4 rounded">
              <p>
                <span class="font-semibold">
                  Invite others to this project by creating an invite code.
                </span>
                Users who use the invite
                code will be added to the project with the role you select below.
              </p>
              <p>
                You can share invite codes with individuals without an Atlos account; they will be prompted to create an account when they use the invite code.
              </p>
            </div>
            <div>
              <%= label(@form, :expires, "Expires") %>
              <div id="invite-expires" phx-update="ignore">
                <%= select(@form, :expires, [
                  {"In 24 hours",
                   NaiveDateTime.utc_now()
                   |> NaiveDateTime.add(24, :hour)
                   |> NaiveDateTime.to_iso8601()},
                  {"In 7 days",
                   NaiveDateTime.utc_now() |> NaiveDateTime.add(7, :day) |> NaiveDateTime.to_iso8601()},
                  {"In 30 days",
                   NaiveDateTime.utc_now()
                   |> NaiveDateTime.add(30, :day)
                   |> NaiveDateTime.to_iso8601()}
                ]) %>
              </div>
              <%= error_tag(@form, :expires) %>
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
                "Create invite",
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
