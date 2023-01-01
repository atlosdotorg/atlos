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
    <article class="w-full xl:max-w-screen-xl md:mx-auto px-4">
      <div class="mb-8 flex border shadow-sm rounded-xl p-4 bg-white flex-col md:flex-row md:justify-between gap-4 border-b pb-4 items-center">
        <h1 class="text-3xl font-medium heading">
          <span class="font-mono text-neutral-500 text-lg flex items-center gap-2">
            <svg
              viewBox="0 0 100 100"
              xmlns="http://www.w3.org/2000/svg"
              fill={@project.color}
              class="h-4 w-4"
            >
              <circle cx="50" cy="50" r="50" />
            </svg>
            <%= @project.code %>
            <br />
          </span>
          <%= @project.name %>
        </h1>
        <%= if Projects.can_edit_project?(@current_user, @project) do %>
          <.link patch={"/projects/#{@project.id}/edit"} class="button ~urge @high">
            Manage Project
          </.link>
        <% end %>
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
