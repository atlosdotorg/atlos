defmodule PlatformWeb.ProjectsLive.Show do
  use PlatformWeb, :live_view

  alias Platform.Projects

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    project = Projects.get_project!(id)

    {:noreply,
     socket
     |> assign(:title, project.name)
     |> assign(:project, project)}
  end

  def handle_info({:close, _project}, socket) do
    {:noreply, socket |> push_patch(to: "/projects/#{socket.assigns.project.id}")}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> push_patch(to: "/projects/#{socket.assigns.project.id}")}
  end

  def render(assigns) do
    ~H"""
    <article class="w-full px-4 md:px-8">
      <div class="mb-8">
        <h1 class="text-3xl font-medium heading">
          <%= @project.name %>
        </h1>
      </div>
      <div>
        Page coming soon...
      </div>
      <%= if @live_action == :edit do %>
        <.modal target={} close_confirmation="Your changes will be lost. Are you sure?">
          <div class="mb-8">
            <p class="sec-head">
              Edit <%= @project.name %>
            </p>
          </div>
          <.live_component
            module={PlatformWeb.ProjectsLive.EditComponent}
            id="edit-project"
            current_user={@current_user}
            project={@project}
          />
        </.modal>
      <% end %>
    </article>
    """
  end
end
