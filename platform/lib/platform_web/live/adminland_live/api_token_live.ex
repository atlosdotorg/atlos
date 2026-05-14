defmodule PlatformWeb.AdminlandLive.APITokenLive do
  use PlatformWeb, :live_component
  alias Platform.API
  alias Platform.API.APIToken
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
      :tokens,
      API.list_api_tokens()
    )
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket |> redirect(to: Routes.adminland_index_path(socket, :api)) |> assign_tokens()}
  end

  def handle_event("deactivate_token", %{"token" => token_id}, socket) do
    with token <- API.get_api_token!(token_id),
         true <- APIToken.admin_managed?(token),
         {:ok, _} <- API.deactivate_api_token(token) do
      Auditor.log(
        :api_token_deactivated,
        %{description: token.description},
        socket.assigns.parent_socket
      )

      {:noreply,
       socket |> put_flash(:info, "API token deactivated successfully.") |> assign_tokens()}
    else
      _ -> {:noreply, socket |> put_flash(:info, "Unable to deactivate API token.")}
    end
  end

  def render(assigns) do
    ~H"""
    <section class="flex-1 flex flex-col mb-8 grow">
      <div class="flow-root">
        <div>
          <div class="inline-block min-w-full">
            <div class="mb-8 bg-urge-50 border border-urge-400 aside ~urge prose text-sm w-full min-w-full">
              <p>
                <strong class="text-blue-800">
                  Admins create
                  <a class="text-blue-800" href="https://docs.atlos.org/admin/api/">
                    instance-wide v2 tokens
                  </a>
                  here.
                </strong>
                These grant full v2 API access across every project on this instance. Project-scoped v2 tokens are listed here for visibility but are managed by project owners from the project's Access page. Legacy v1 tokens are deprecated and can no longer be created. Learn more in our <a
                  class="text-blue-800"
                  href="https://docs.atlos.org/admin/api/"
                >admin API documentation</a>.
              </p>
            </div>
            <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
              <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
                <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
                  <table class="min-w-full divide-y divide-gray-300">
                    <thead class="bg-gray-50">
                      <tr>
                        <th
                          scope="col"
                          class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
                        >
                          Name
                        </th>
                        <th
                          scope="col"
                          class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900"
                        >
                          Last used
                        </th>
                        <th
                          scope="col"
                          class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900"
                        >
                          Created
                        </th>
                        <th
                          scope="col"
                          class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900"
                        >
                          Permissions
                        </th>
                        <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6 text-right">
                          <.link
                            class="button ~urge @high"
                            patch={Routes.adminland_index_path(@socket, :api_new)}
                          >
                            Create
                          </.link>
                          <span class="sr-only">Deactivate</span>
                        </th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-200 bg-white">
                      <tr :if={Enum.empty?(@tokens)} class="text-center py-8 text-gray-500">
                        <td class="py-4 px-4 bg-neutral-50" colspan="5">
                          No API tokens have been created.
                        </td>
                      </tr>
                      <tr :for={token <- @tokens} id={token.id}>
                        <td class="py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                          <%= token.name %>
                          <span :if={!is_nil(token.description)} data-tooltip={token.description}>
                            <Heroicons.information_circle
                              mini
                              class="h-4 w-4 text-gray-400 inline-block"
                            />
                          </span>
                          <span :if={token.is_legacy} class="chip ~warning ml-2">Legacy v1</span>
                          <span
                            :if={!token.is_legacy and is_nil(token.project_id)}
                            class="chip ~urge ml-2"
                          >
                            Instance-wide v2
                          </span>
                          <span :if={!is_nil(token.project_id)} class="chip ~positive ml-2">
                            Project-scoped v2
                          </span>
                          <span
                            :if={not token.is_active}
                            class="chip ~critical ml-2"
                            data-tooltip="This token has been deactivated and can no longer be used."
                          >
                            Deactivated
                          </span>
                        </td>
                        <td class="px-3 py-4 text-sm text-gray-500">
                          <%= if not is_nil(token.last_used) do %>
                            <%= token.last_used |> Date.to_string() %>
                          <% else %>
                            Never
                          <% end %>
                        </td>
                        <td class="px-3 py-4 text-sm text-gray-500">
                          <.rel_time time={token.inserted_at} />
                          <%= if not is_nil(token.creator) do %>
                            by <.user_text user={token.creator} />
                          <% end %>
                        </td>
                        <td class="px-3 py-4 text-sm text-gray-500">
                          <div class="flex flex-wrap gap-1">
                            <%= for permission <- token.permissions do %>
                              <span class="chip ~neutral"><%= permission %></span>
                            <% end %>
                          </div>
                        </td>
                        <td class="relative py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                          <button
                            :if={APIToken.admin_managed?(token) and token.is_active}
                            phx-click="deactivate_token"
                            phx-value-token={token.id}
                            phx-target={@myself}
                            data-confirm={"Are you sure you want to deactivate the token \"#{token.name}\"? This action cannot be undone."}
                            data-tooltip={"Deactivate " <> token.name}
                          >
                            <Heroicons.minus_circle mini class="h-5 w-5" />
                            <span class="sr-only">Deactivate <%= token.name %></span>
                          </button>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <%= if @show_creation_modal do %>
        <.modal target={@myself} close_confirmation={}>
          <p class="sec-head">
            New API Token
          </p>
          <.live_component
            module={PlatformWeb.AdminlandLive.APITokenCreateLive}
            id="new-token"
            parent_socket={@parent_socket}
          />
        </.modal>
      <% end %>
    </section>
    """
  end
end
