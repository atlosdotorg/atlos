defmodule PlatformWeb.AdminlandLive.APITokenCreateLive do
  use PlatformWeb, :live_component
  alias Platform.API
  alias Platform.Auditor

  def update(%{parent_socket: parent_socket} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:parent_socket, parent_socket)
     |> assign(:token, nil)
     |> assign(:changeset, API.change_api_token(%API.APIToken{permissions: [:read]}))}
  end

  def handle_event("validate", %{"api_token" => params}, socket) do
    changeset =
      API.change_api_token(%API.APIToken{}, params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def handle_event("save", %{"api_token" => params}, socket) do
    current_user = socket.assigns.parent_socket.assigns.current_user

    # Adminland only mints instance-wide v2 tokens. Legacy v1 tokens are
    # deprecated; existing ones keep working but no new ones can be created
    # through the UI.
    with {:ok, value} <- API.create_api_token(nil, current_user, params, legacy: false) do
      Auditor.log(
        :api_token_created,
        %{description: value.description},
        socket.assigns.parent_socket
      )

      {:noreply, socket |> assign(:token, value)}
    else
      {:error, changeset} -> {:noreply, socket |> assign(:changeset, changeset)}
    end
  end

  def render(assigns) do
    ~H"""
    <section>
      <%= if is_nil(@token) do %>
        <.form
          :let={f}
          for={@changeset}
          id="api-token-create"
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save"
          class="phx-form"
        >
          <p class="text-sm text-gray-600 mb-6">
            This will create an <span class="font-medium">instance-wide v2</span>
            API token, which grants access across every project on this instance. Treat the resulting token with care.
          </p>

          <%= label(f, :name, "What should we call this token?") %>
          <%= text_input(f, :name) %>
          <p class="support">
            This name will be visible to admins and to members of any project in which this token performs an action.
          </p>
          <%= error_tag(f, :name) %>

          <%= label(f, :description, "How will you use this API token?") %>
          <%= textarea(f, :description,
            placeholder: "Some information about this token...",
            phx_debounce: "250",
            rows: 3
          ) %>
          <p class="support">
            This is just for your reference, so you can remember what this token is for. It will be visible to other admins.
          </p>
          <%= error_tag(f, :description) %>

          <div class="mt-6">
            <%= label(f, :permissions, "What permissions should this token have?") %>
            <div id="admin-permissions-select" phx-update="ignore">
              <%= multiple_select(
                f,
                :permissions,
                [
                  {"Read", "read"},
                  {"Comment", "comment"},
                  {"Edit", "edit"}
                ],
                "data-descriptions":
                  Jason.encode!(%{
                    "read" =>
                      "Can read incidents, source material, comments, and updates across all projects",
                    "comment" => "Can add comments to incidents in any project",
                    "edit" =>
                      "Can create incidents, edit attributes, and upload media versions in any project"
                  }),
                "data-required": Jason.encode!(["read"])
              ) %>
            </div>
            <%= error_tag(f, :permissions) %>
          </div>

          <%= submit(
            "Create API Token",
            phx_disable_with: "Creating...",
            class: "button ~urge @high mt-4"
          ) %>
        </.form>
      <% else %>
        <div class="text-center">
          <p class="flex justify-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-12 w-12 text-positive-600"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </p>
          <h2 class="font-mono text-lg font-medium my-2"><%= @token.value %></h2>
          <p class="text-gray-600 text-sm">
            Your API token "<%= @token.name %>" is shown above. Be sure to store it somewhere, as you won't be able to see it again.
          </p>
          <p class="mt-4">
            <.link class="text-button text-sm" patch={Routes.adminland_index_path(@socket, :api)}>
              Close
            </.link>
          </p>
        </div>
      <% end %>
    </section>
    """
  end
end
