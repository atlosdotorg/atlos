defmodule PlatformWeb.AdminlandLive.InvitesLive do
  use PlatformWeb, :live_component
  alias Platform.Accounts
  alias Platform.Invites

  def update(%{current_user: current_user} = assigns, socket) do
    # Double check permissions
    if not Accounts.is_privileged(current_user) do
      raise PlatformWeb.Errors.Unauthorized, "No permission"
    end

    {:ok,
     socket
     |> assign(assigns)
     |> assign_invites()}
  end

  defp assign_invites(socket) do
    assign(
      socket,
      :invites,
      Invites.list_invites()
      |> Enum.filter(&Invites.is_invite_active/1)
      |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
    )
  end

  def handle_event("deactivate_invite", %{"id" => invite_id}, socket) do
    # Triple check permissions
    if not Accounts.is_privileged(socket.assigns.current_user) do
      raise PlatformWeb.Errors.Unauthorized, "No permission"
    end

    invite = Invites.get_invite!(invite_id)
    {:ok, _} = Invites.update_invite(invite, %{"active" => false})
    {:noreply, socket |> assign_invites()}
  end

  def handle_event("generate_invite", %{"expires" => expires, "single" => single_use}, socket) do
    # Triple check permissions
    if not Accounts.is_privileged(socket.assigns.current_user) do
      raise PlatformWeb.Errors.Unauthorized, "No permission"
    end

    {:ok, _} =
      Invites.create_invite(%{
        owner_id: socket.assigns.current_user.id,
        expires: expires,
        single_use: single_use == "true"
      })

    {:noreply, socket |> assign_invites()}
  end

  def render(assigns) do
    ~H"""
    <article class="flex flex-col gap-8">
      <div class="flex flex-wrap gap-4">
        <%= for single_use <- ["true", "false"] do %>
          <%= for timedelta <- [1, 7, 30] do %>
            <% expiry = NaiveDateTime.utc_now() |> NaiveDateTime.add(timedelta, :day) %>
            <button
              phx-target={@myself}
              phx-click="generate_invite"
              phx-value-single={single_use}
              phx-value-expires={expiry |> NaiveDateTime.to_iso8601()}
              class="base-button text-neutral-500"
            >
              +&nbsp;<span class="text-neutral-800"><%= if single_use == "true" do %>
                Single use&nbsp;
              <% else %>
                Multi use&nbsp;
              <% end %></span> invite expiring&nbsp;<span class="text-neutral-800"><.rel_time time={
                  expiry
                } /></span>
            </button>
          <% end %>
        <% end %>
      </div>
      <%= if Enum.empty?(@invites) do %>
        <div class="text-center">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="mx-auto h-8 w-8 text-gray-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z"
            />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No invite codes</h3>
          <p class="mt-1 text-sm text-gray-500">Get started by creating an invite code</p>
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
                    <th scope="col" class="pr-3 text-left text-sm font-semibold text-gray-900 py-4">
                      Expires
                    </th>
                    <th scope="col" class="pr-3 text-left text-sm font-semibold text-gray-900 py-4">
                      Single Use
                    </th>
                    <th scope="col" class="pr-3 text-left text-sm font-semibold text-gray-900 py-4">
                      Creator
                    </th>
                    <th scope="col" class="pr-3 text-left text-sm font-semibold text-gray-900 py-4">
                      Project
                    </th>
                    <th scope="col" class="pr-3 text-left text-sm font-semibold text-gray-900 py-4">
                      Users
                    </th>
                    <th
                      scope="col"
                      class="pr-3 text-left text-sm font-semibold text-gray-900 py-4"
                      data-tooltip="Users who use this invite will be added to the project with this role."
                    >
                      Role
                    </th>
                    <th scope="col" class="relative pl-3 pr-4 sm:pr-2 text-right lg:whitespace-nowrap">
                      <span class="sr-only">Manage</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= for invite <- @invites do %>
                    <tr>
                      <td
                        class="pl-4 py-3 sm:pl-6 pr-3 text-sm font-medium text-urge-600"
                        x-data="{pulse: false}"
                      >
                        <button
                          type="button"
                          class="flex items-center gap-2"
                          x-bind:class="pulse ? 'animate-ping' : ''"
                          x-on:click={"window.setClipboard(#{Jason.encode!(Routes.invite_url(@socket, :new, invite.code))}); pulse = true; setTimeout(() => pulse = false, 500)"}
                        >
                          <Heroicons.link mini class="h-5 w-5 text-urge-400" />
                          <span class="truncate">
                            Copy Link
                          </span>
                        </button>
                      </td>
                      <td class="pr-3 text-sm text-gray-600">
                        <.rel_time time={invite.expires} />
                      </td>
                      <td class="pr-3 text-sm text-gray-600">
                        <%= if invite.single_use do %>
                          Yes
                        <% else %>
                          No
                        <% end %>
                      </td>
                      <td class="pr-3 text-sm text-gray-600 -ml-2">
                        <%= if is_nil(invite.owner) do %>
                          Unknown
                        <% else %>
                          <.user_text user={invite.owner} icon={true} profile_photo_class="h-6 w-6" />
                        <% end %>
                      </td>
                      <td class="pr-3 text-sm text-gray-600 -ml-2">
                        <%= if not is_nil(invite.project), do: invite.project.name, else: nil %>
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
                            <% _ -> %>
                              N/A
                          <% end %>
                        </div>
                      </td>
                      <td class="relative pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                        <%= if Invites.is_invite_active(invite) do %>
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
    </article>
    """
  end
end
