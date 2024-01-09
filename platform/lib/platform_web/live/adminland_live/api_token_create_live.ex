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
     |> assign(:changeset, API.change_api_token(%API.APIToken{}))}
  end

  def handle_event("validate", %{"api_token" => params}, socket) do
    changeset =
      API.change_api_token(%API.APIToken{}, params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def handle_event("save", %{"api_token" => params}, socket) do
    with {:ok, value} <- API.create_api_token(params, legacy: true) do
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
          <%= label(f, :name, "What should we call this token?") %>
          <%= text_input(f, :name) %>
          <p class="support">
            This name will be visible to members of the project and associated with any actions performed by the token.
          </p>
          <%= error_tag(f, :name) %>

          <%= label(f, :description, "How will you use this API token?") %>
          <%= textarea(f, :description,
            placeholder: "Some information about this token...",
            phx_debounce: "250",
            rows: 3
          ) %>
          <p class="support">
            This is just for your reference, so you can remember what this token is for. It will be visible to other project owners.
          </p>
          <%= error_tag(f, :description) %>

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
            Your API token "<%= @token.description %>" is shown above. Be sure to store it somewhere, as you won't be able to see it again.
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
