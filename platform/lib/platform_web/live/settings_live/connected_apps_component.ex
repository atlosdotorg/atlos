defmodule PlatformWeb.SettingsLive.ConnectedAppsComponent do
  use PlatformWeb, :live_component

  alias Platform.OAuth

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:grants, OAuth.list_active_grants(assigns.current_user))}
  end

  def handle_event("revoke", %{"grant-id" => grant_id}, socket) do
    user = socket.assigns.current_user

    case OAuth.revoke_user_grant(user, grant_id) do
      :ok ->
        Platform.Auditor.log(:oauth_grant_revoked, %{grant_id: grant_id}, socket)
        {:noreply, assign(socket, :grants, OAuth.list_active_grants(user))}

      {:error, :not_found} ->
        {:noreply, assign(socket, :grants, OAuth.list_active_grants(user))}
    end
  end

  def render(assigns) do
    ~H"""
    <article class="text-sm">
      <%= if Enum.empty?(@grants) do %>
        <p class="text-neutral-600">
          You haven't connected any applications. When you connect an AI assistant or other MCP
          client to Atlos, it will appear here.
        </p>
      <% else %>
        <ul class="divide-y">
          <li :for={grant <- @grants} class="flex items-center justify-between gap-4 py-3">
            <div>
              <p class="font-medium text-neutral-800"><%= grant.client.client_name %></p>
              <p class="text-neutral-600">
                All your projects &middot; <%= Enum.join(grant.scopes, ", ") %>
              </p>
              <p class="text-neutral-500 text-xs">
                Connected <.rel_time time={grant.inserted_at} />
                <%= if grant.last_used_at do %>
                  &middot; last used <.rel_time time={DateTime.to_naive(grant.last_used_at)} />
                <% end %>
              </p>
            </div>
            <button
              type="button"
              class="base-button"
              phx-click="revoke"
              phx-value-grant-id={grant.id}
              phx-target={@myself}
              data-confirm={"Disconnect #{grant.client.client_name}? It will lose access immediately."}
            >
              Disconnect
            </button>
          </li>
        </ul>
      <% end %>
    </article>
    """
  end
end
