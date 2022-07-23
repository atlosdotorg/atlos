defmodule PlatformWeb.AdminlandLive.APITokenLive do
  use PlatformWeb, :live_component
  alias Platform.API
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

  def handle_event("delete_token", %{"token" => token_id}, socket) do
    with token <- API.get_api_token!(token_id),
         {:ok, _} <- API.delete_api_token(token) |> IO.inspect() do
      Auditor.log(:api_token_deleted, %{description: token.description}, socket)
      {:noreply, socket |> put_flash(:info, "API token deleted successfully.") |> assign_tokens()}
    else
      _ -> {:noreply, socket |> put_flash(:info, "Unable to delete API token.")}
    end
  end

  def render(assigns) do
    ~H"""
    <section class="max-w-3xl mx-auto">
      <div class="mt-8 flex flex-col">
        <div class="-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle md:px-6 lg:px-8">
            <%= if length(@tokens) > 0 do %>
              <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
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
                        Created
                      </th>
                      <th scope="col" class="py-3.5 pl-3 pr-4 sm:pr-6">
                        <span class="sr-only">More Actions</span>
                        <%= live_patch("New Token",
                          class: "button ~urge @high float-right",
                          to: Routes.adminland_index_path(@socket, :api_new)
                        ) %>
                      </th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-200 bg-white">
                    <%= for token <- @tokens do %>
                      <tr>
                        <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm sm:pl-6">
                          <%= token.description %>
                        </td>
                        <td class="max-w-md px-3 py-4 text-sm text-gray-500">
                          <.rel_time time={token.inserted_at} />
                        </td>
                        <td class="pl-3 pr-4 sm:pr-6">
                          <button
                            phx-click="delete_token"
                            phx-value-token={token.id}
                            phx-target={@myself}
                            data-confirm="Are you sure you want to delete this API token?"
                            class="font-medium text-critical-500 hover:text-critical-700 float-right text-sm"
                          >
                            Delete
                          </button>
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
                <h3 class="mt-2 text-sm font-medium text-gray-900">No API tokens</h3>
                <p class="mt-1 text-sm text-gray-500">Get started by creating a new API token.</p>
                <div class="mt-6">
                  <%= live_patch("New Token",
                    class: "button ~urge @high",
                    to: Routes.adminland_index_path(@socket, :api_new)
                  ) %>
                </div>
              </div>
            <% end %>
            <div class="bg-urge-50 border border-urge-400 mx-auto aside ~urge prose text-sm mt-8 w-full">
              <p>
                <strong class="text-blue-800">
                  The Atlos API is a read-only API for administrators.
                </strong>
                You can learn more about the API authentication scheme and endpoints below.
              </p>
              <details class="-mt-2">
                <summary class="cursor-pointer font-medium">How to use the API</summary>
                <p>The Atlos API supports the following endpoints:</p>
                <ul>
                  <li>
                    <code>/api/v1/media</code>
                    &mdash; returns all incidents, with the most recently modified incidents listed first (internally, incidents are called media &mdash; that is, collections of individual pieces of media)
                  </li>
                  <li>
                    <code>/api/v1/media_versions</code>
                    &mdash; returns all media versions, with the most recently modified media versions listed first
                  </li>
                </ul>
                <p>
                  All endpoints return 30 results at a time. You can paginate using the
                  <code>cursor</code> query parameter, whose value is provided by the
                  <code>next</code> and <code>previous</code>
                  keys in the response. Results are available under the <code>results</code> key.
                </p>
                <p>
                  To authenticate against the API, include a <code>Authorization</code>
                  header and set its value to <code>Bearer &lt;your token&gt;</code>
                  (without the brackets).
                </p>
              </details>
            </div>
          </div>
        </div>
      </div>
      <%= if @show_creation_modal do %>
        <.modal target={@myself} close_confirmation={}>
          <div class="mb-8">
            <p class="sec-head">
              New API Token
            </p>
            <p class="sec-subhead">
              Note that you will only be able to see the secret value once.
            </p>
          </div>
          <.live_component module={PlatformWeb.AdminlandLive.APITokenCreateLive} id="new-token" />
        </.modal>
      <% end %>
    </section>
    """
  end
end
