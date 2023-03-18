defmodule PlatformWeb.ProjectsLive.Index do
  use PlatformWeb, :live_view

  alias Platform.Projects
  alias Platform.Permissions

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:title, "Projects")
     |> assign(:projects, Projects.list_projects_for_user(socket.assigns.current_user))}
  end

  # Handle the :close message
  def handle_info({:close, project}, socket) do
    {:noreply,
     socket
     |> push_redirect(to: if(project, do: "/projects/#{project.id}/edit", else: "/projects"))}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> push_patch(to: "/projects")}
  end

  def render(assigns) do
    ~H"""
    <article class="w-full xl:max-w-screen-xl md:mx-auto px-4">
      <div class="mb-8 flex flex-col md:flex-row md:justify-between gap-4 pb-4 border-b">
        <h1 class="text-3xl font-medium heading">
          Projects
        </h1>
        <%= if Permissions.can_create_project?(@current_user) do %>
          <.link patch="/projects/new" class="button ~urge @high">
            New Project
          </.link>
        <% end %>
      </div>
      <div>
        <%= if Enum.empty?(@projects) do %>
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
            <h3 class="mt-2 text-sm font-medium text-gray-900">No projects</h3>
            <%= if Permissions.can_create_project?(@current_user) do %>
              <p class="mt-1 text-sm text-gray-500">Get started by creating a new project.</p>
              <div class="mt-6">
                <.link type="button" class="button ~urge @high" patch="/projects/new">
                  New Project
                </.link>
              </div>
            <% end %>
          </div>
        <% end %>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <%= for project <- @projects do %>
            <.project_card project={project} />
          <% end %>
        </div>
      </div>
      <%= if @live_action == :new do %>
        <.modal target={} close_confirmation="Your changes will be lost. Are you sure?">
          <div class="mb-8">
            <p class="sec-head">
              New Project
            </p>
          </div>
          <.live_component
            module={PlatformWeb.ProjectsLive.EditComponent}
            id="new-project"
            current_user={@current_user}
            show_panes={[:general]}
          />
        </.modal>
      <% end %>
    </article>
    """
  end
end
