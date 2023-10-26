defmodule PlatformWeb.SettingsLive.InvitesComponent do
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
      Invites.get_invites_by_user(socket.assigns.current_user)
      |> Enum.filter(& &1.active)
      |> Enum.sort_by(& &1.inserted_at, {:asc, NaiveDateTime})
      |> Enum.reverse()
    )
  end

  def handle_event("generate_invite", _params, socket) do
    # Triple check permissions
    if not Accounts.is_privileged(socket.assigns.current_user) do
      raise PlatformWeb.Errors.Unauthorized, "No permission"
    end

    # First, invalidate all existing invite codes
    for invite <- Invites.get_invites_by_user(socket.assigns.current_user) do
      Invites.update_invite(invite, %{active: false})
    end

    Invites.create_invite(%{owner_id: socket.assigns.current_user.id})
    {:noreply, socket |> assign_invites()}
  end

  def render(assigns) do
    ~H"""
    <article>
      <%= if length(@invites) == 0 do %>
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
          <h3 class="mt-2 text-sm font-medium text-gray-900">No invite code</h3>
          <p class="mt-1 text-sm text-gray-500">Get started by creating an invite code</p>
          <div class="mt-6">
            <button
              type="button"
              phx-click="generate_invite"
              phx-target={@myself}
              class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-urge-600 hover:bg-urge-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-urge-500"
            >
              + Create Invite
            </button>
          </div>
        </div>
      <% else %>
        <div class="grid grid-cols-1 gap-4 divide-y">
          <%= for invite <- @invites do %>
            <div>
              <article class="flex justify-between items-center">
                <div class="font-mono text-2xl">
                  <%= invite.code %>
                </div>

                <div>
                  <button
                    type="button"
                    phx-click="generate_invite"
                    data-confirm="This will regenerate your invite code. Individiduals will no longer be able to sign up with your old invite code."
                    phx-target={@myself}
                    class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-urge-600 hover:bg-urge-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-urge-500"
                  >
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="h-4 w-4 mr-1"
                      viewBox="0 0 20 20"
                      fill="currentColor"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z"
                        clip-rule="evenodd"
                      />
                    </svg>
                    Regenerate
                  </button>
                </div>
              </article>
              <article class="bg-gray-100 rounded p-4 mt-4 text-sm">
                <% join_url =
                  Routes.user_registration_url(@socket, :new) <> "?invite_code=#{invite.code}" %> To apply this invite code automatically, users should join via this URL:
                <a class="font-mono text-urge-600" href={join_url}><%= join_url %></a>
              </article>
            </div>
          <% end %>
        </div>
      <% end %>
    </article>
    """
  end
end
