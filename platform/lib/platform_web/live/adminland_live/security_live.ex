defmodule PlatformWeb.AdminlandLive.SecurityLive do
  use PlatformWeb, :live_component
  alias Platform.Security
  alias Platform.Auditor

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_tokens()}
  end

  def assign_tokens(socket) do
    socket
    |> assign(
      :security_modes,
      Security.list_security_modes()
    )
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> redirect(to: Routes.adminland_index_path(socket, :security))}
  end

  def handle_event("reset_sessions", _params, socket) do
    Auditor.log(:reset_all_sessions, %{}, socket)

    Platform.Accounts.delete_all_session_tokens()

    {:noreply, socket |> redirect(to: Routes.adminland_index_path(socket, :security))}
  end

  def render(assigns) do
    ~H"""
    <section class="max-w-3xl mx-auto">
      <div class="mt-8 flex flex-col">
        <div class="-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle md:px-6 lg:px-8">
            <.card>
              <:header>
                <div class="md:flex justify-between items-center">
                  <p class="sec-head">Security Mode</p>
                  <%= live_patch("Change Security Mode",
                    class: "button ~urge @high float-right",
                    to: Routes.adminland_index_path(@socket, :security_mode_create)
                  ) %>
                </div>
              </:header>
              <div class="aside ~neutral text-sm mb-4">
                <p>
                  <strong class="font-semibold">
                    Security modes enable admins to quickly restrict behavior on Atlos.
                  </strong>
                  Security modes can be useful for scheduled maintenance, or for responding to potential security incidents. Admins have the ability to restrict editing by all non-admin users, or to block all non-admin users from accessing Atlos.
                </p>
              </div>
              <%= if length(@security_modes) > 0 do %>
                <div class="overflow-hidden">
                  <table class="min-w-full divide-y divide-gray-300">
                    <thead class="bg-white">
                      <tr>
                        <th
                          scope="col"
                          class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
                        >
                          Description
                        </th>
                        <th
                          scope="col"
                          class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900"
                        >
                          Set
                        </th>
                        <th
                          scope="col"
                          class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900"
                        >
                          Mode
                        </th>
                        <th
                          scope="col"
                          class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900"
                        >
                          User
                        </th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-200 bg-white">
                      <%= for mode <- @security_modes do %>
                        <tr>
                          <td class="py-4 pl-4 pr-3 text-sm sm:pl-6">
                            <%= mode.description %>
                          </td>
                          <td class="max-w-md px-3 py-4 text-sm text-gray-500">
                            <.rel_time time={mode.inserted_at} />
                          </td>
                          <td class="max-w-md px-3 py-4 text-sm text-gray-500 font-mono">
                            <%= mode.mode %>
                          </td>
                          <td class="max-w-md px-3 py-4 text-sm text-gray-500">
                            <.user_text user={mode.user} />
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% else %>
                <div class="text-center">
                  <svg
                    class="mx-auto h-12 w-12 text-gray-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    aria-hidden="true"
                  >
                    <path
                      vector-effect="non-scaling-stroke"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M9 13h6m-3-3v6m-9 1V7a2 2 0 012-2h6l2 2h6a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2z"
                    />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No security mode changes</h3>
                  <p class="mt-1 text-sm text-gray-500">You can change the security mode below.</p>
                  <div class="mt-6">
                    <%= live_patch("Change Security Mode",
                      class: "button ~urge @high",
                      to: Routes.adminland_index_path(@socket, :security_mode_create)
                    ) %>
                  </div>
                </div>
              <% end %>
            </.card>
            <hr class="sep h-8" />
            <.card>
              <div class="md:flex items-center justify-between">
                <div>
                  <p class="sec-head">Reset All Sessions</p>
                  <p class="sec-subhead">In an emergency, you can easily log everyone out.</p>
                </div>
                <button
                  class="button ~critical @high"
                  data-confirm="Are you sure you would like to log everyone out? This will log you out as well."
                  phx-click="reset_sessions"
                  phx-target={@myself}
                >
                  Reset All Sessions
                </button>
              </div>
            </.card>
          </div>
        </div>
      </div>
      <%= if @show_creation_modal do %>
        <.modal target={@myself} close_confirmation={}>
          <div class="mb-8">
            <p class="sec-head">
              New security mode
            </p>
          </div>
          <.live_component
            module={PlatformWeb.AdminlandLive.SecurityModeCreateLive}
            id="new-mode"
            parent_socket={@parent_socket}
          />
        </.modal>
      <% end %>
    </section>
    """
  end
end
