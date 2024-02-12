defmodule PlatformWeb.ProjectsLive.APITokensComponent do
  use PlatformWeb, :live_component

  alias Platform.API
  alias Platform.API.APIToken
  alias Platform.Auditor
  alias Platform.Permissions

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_tokens()
     |> assign(:show_token, nil)
     |> assign(:changeset, nil)}
  end

  def assign_tokens(socket) do
    assign(
      socket,
      :tokens,
      API.list_api_tokens_for_project(socket.assigns.project)
      |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
    )
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
      |> Map.put("creator_id", socket.assigns.current_user.id)

    if not can_edit(socket) do
      raise PlatformWeb.Errors.Unauthorized, "You do not have permission to edit this project"
    end

    API.change_api_token(%APIToken{}, params)
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> assign_changeset(nil) |> assign(:show_token, nil)}
  end

  def handle_event("add_token", _params, socket) do
    {:noreply,
     socket
     |> assign_changeset(changeset(socket))}
  end

  def handle_event("deactivate_token", %{"id" => token_id}, socket) do
    if not can_edit(socket) do
      raise PlatformWeb.Errors.Unauthorized, "You do not have permission to edit this project"
    end

    # We look through the tokens in the socket, rather than fetching them again,
    # because we want to make sure that we only allow deleting tokens that are
    # associated with the project.
    token = socket.assigns.tokens |> Enum.find(&(&1.id == token_id))

    {:ok, _} = API.deactivate_api_token(token)

    Auditor.log(
      :api_token_deactivated,
      socket.assigns.current_user,
      %{
        project_id: socket.assigns.project.id
      }
    )

    {:noreply,
     socket
     |> assign_tokens()}
  end

  def handle_event("validate", %{"api_token" => params}, socket) do
    cs =
      changeset(socket, params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign_changeset(cs)}
  end

  def handle_event("close_token_display", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_token, nil)}
  end

  def handle_event("save", %{"api_token" => params}, socket) do
    cs = changeset(socket, params)

    if cs.valid? do
      params =
        params
        |> Map.put("project_id", socket.assigns.project.id)
        |> Map.put("creator_id", socket.assigns.current_user.id)

      result = API.create_api_token(params)

      case result do
        {:ok, token} ->
          Auditor.log(
            :api_token_created,
            socket.assigns.current_user,
            %{
              project_id: socket.assigns.project.id,
              creator_id: token.creator_id,
              token_id: token.id
            }
          )

          {:noreply,
           socket
           |> assign_changeset(nil)
           |> assign(:show_token, token)
           |> assign_tokens()}

        {:error, changeset} ->
          {:noreply, socket |> assign_changeset(changeset |> Map.put(:action, :validate))}
      end
    else
      {:noreply, socket |> assign_changeset(cs |> Map.put(:action, :validate))}
    end
  end

  def can_edit(socket) do
    Permissions.can_edit_project_api_tokens?(socket.assigns.current_user, socket.assigns.project)
  end

  def render(assigns) do
    ~H"""
    <div>
      <% can_edit = Permissions.can_edit_project_api_tokens?(@current_user, @project) %>
      <div :if={can_edit} class="flex flex-col lg:flex-row gap-4 pt-8 w-full">
        <div class="mb-4 lg:w-[20rem] lg:mr-16">
          <p class="sec-head text-xl">API Tokens</p>
          <p class="sec-subhead">
            Use API tokens to connect your project to external services. You can create multiple tokens with different permissions.
          </p>
        </div>
        <section class="flex flex-col mb-8 grow">
          <div class="flow-root">
            <div>
              <div class="inline-block min-w-full">
                <div class="mb-8 bg-urge-50 border border-urge-400 aside ~urge prose text-sm w-full min-w-full">
                  <p>
                    <strong class="text-blue-800">
                      The beta
                      <a class="text-blue-800" href="https://docs.atlos.org/technical/api/">
                        Atlos API
                      </a>
                      allows you to connect your project to external services.
                    </strong>
                    API tokens are sensitive, as they allow access to your project. Learn more about how to use the Atlos API in our <a
                      class="text-blue-800"
                      href="https://docs.atlos.org/technical/api/"
                    >documentation</a>.
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
                              <%= if can_edit do %>
                                <button
                                  type="button"
                                  class="button ~urge @high"
                                  phx-click="add_token"
                                  phx-target={@myself}
                                >
                                  Create
                                </button>
                              <% end %>
                              <span class="sr-only">Deactivate</span>
                            </th>
                          </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-200 bg-white">
                          <tr :if={Enum.empty?(@tokens)} class="text-center py-8 text-gray-500">
                            <td class="py-4 px-4 bg-neutral-50">
                              No API tokens have been created for this project.
                            </td>
                          </tr>
                          <tr :for={token <- @tokens} id={token.id}>
                            <td class=" py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                              <%= token.name %>
                              <span :if={!is_nil(token.description)} data-tooltip={token.description}>
                                <Heroicons.information_circle
                                  mini
                                  class="h-4 w-4 text-gray-400 inline-block"
                                />
                              </span>
                              <%= if token.is_legacy do %>
                                <span class="chip ~warning ml-2">Legacy</span>
                              <% end %>
                              <%= if not token.is_active do %>
                                <span
                                  class="chip ~critical ml-2"
                                  data-tooltip="This token has been deactivated and can no longer be used."
                                >
                                  Deactivated
                                </span>
                              <% end %>
                            </td>
                            <td class=" px-3 py-4 text-sm text-gray-500">
                              <%= if not is_nil(token.last_used) do %>
                                <%= token.last_used |> Date.to_string() %>
                              <% else %>
                                Never
                              <% end %>
                            </td>
                            <td class=" px-3 py-4 text-sm text-gray-500">
                              <.rel_time time={token.inserted_at} /> by
                              <.user_text user={token.creator} />
                            </td>
                            <td class=" px-3 py-4 text-sm text-gray-500 flex flex-wrap gap-1">
                              <%= for permission <- token.permissions do %>
                                <span class="chip ~neutral">
                                  <%= permission %>
                                </span>
                              <% end %>
                            </td>
                            <td class="relative  py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                              <%= if token.is_active do %>
                                <button
                                  type="button"
                                  phx-click="deactivate_token"
                                  phx-target={@myself}
                                  data-confirm={"Are you sure you want to deactivate the token \"#{token.name}\"? This action cannot be undone."}
                                  phx-value-id={token.id}
                                  class="text-neutral-600 hover:text-neutral-900"
                                  data-tooltip={"Deactivate " <> token.name}
                                >
                                  <Heroicons.minus_circle mini class="h-5 w-5" />
                                  <span class="sr-only">Deactivate <%= token.name %></span>
                                </button>
                              <% end %>
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
          <%= if not is_nil(@show_token) do %>
            <.modal
              target={@myself}
              close_confirmation="Be sure to store your token, as you won't be able to see it again."
            >
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
                <h2 class="font-mono text-lg font-medium my-2"><%= @show_token.value %></h2>
                <p class="text-gray-600 text-sm">
                  Your API token "<%= @show_token.name %>" is shown above. Be sure to store it somewhere safe, as you won't be able to see it again.
                </p>
                <p class="mt-4">
                  <button
                    type="button"
                    class="text-button text-sm"
                    phx-click="close_token_display"
                    phx-target={@myself}
                  >
                    Close
                  </button>
                </p>
              </div>
            </.modal>
          <% end %>
          <%= if not is_nil(@changeset) and can_edit do %>
            <.modal target={} close_confirmation="Your changes will be lost. Are you sure?">
              <div class="mb-8">
                <p class="sec-head">
                  Create an API token
                </p>
              </div>
              <.form
                for={@form}
                class="flex flex-col space-y-8 phx-form"
                phx-change="validate"
                phx-submit="save"
                phx-target={@myself}
              >
                <div>
                  <%= label(
                    @form,
                    :name,
                    "What do you want to call this token?"
                  ) %>
                  <%= text_input(
                    @form,
                    :name,
                    placeholder: "The name of the token...",
                    phx_debounce: 1000
                  ) %>
                  <p class="support">
                    This name will be visible to members of the project and associated with any actions performed by the token.
                  </p>
                  <%= error_tag(@form, :name) %>
                </div>

                <div>
                  <%= label(
                    @form,
                    :description,
                    "How will you use this API token?"
                  ) %>
                  <%= textarea(
                    @form,
                    :description,
                    placeholder: "Some information about this token...",
                    phx_debounce: 250,
                    rows: 3
                  ) %>
                  <p class="support">
                    This is just for your reference, so you can remember what this token is for. It will be visible to other project owners.
                  </p>
                  <%= error_tag(@form, :description) %>
                </div>

                <div>
                  <%= label(
                    @form,
                    :permissions,
                    "What permissions should this token have?"
                  ) %>
                  <div id="permissions-select" phx-update="ignore">
                    <%= multiple_select(
                      @form,
                      :permissions,
                      [
                        {"Read", "read"},
                        {"Comment", "comment"},
                        {"Edit", "edit"}
                      ],
                      "data-descriptions":
                        Jason.encode!(%{
                          "read" =>
                            "Can read incidents and comments, including hidden and restricted incidents",
                          "comment" => "Can add comments to incidents",
                          "edit" => "Can edit incidents' attributes and metadata"
                        }),
                      "data-required": Jason.encode!(["read"])
                    ) %>
                  </div>
                  <%= error_tag(@form, :permissions) %>
                </div>

                <div>
                  <%= submit(
                    "Create Token",
                    phx_disable_with: "Saving...",
                    class: "button ~urge @high"
                  ) %>
                </div>
              </.form>
            </.modal>
          <% end %>
        </section>
      </div>
    </div>
    """
  end
end
