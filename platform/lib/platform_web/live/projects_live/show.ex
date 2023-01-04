defmodule PlatformWeb.ProjectsLive.Show do
  use PlatformWeb, :live_view

  alias Platform.Projects
  alias Platform.Material

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    project = Projects.get_project!(id)

    {:noreply,
     socket
     |> assign(:title, project.name)
     |> assign(:project, project)
     |> assign(:full_width, true)
     |> assign(:status_statistics, Material.status_overview_statistics(project_id: project.id))}
  end

  def handle_info({:close, _project}, socket) do
    {:noreply, socket |> push_patch(to: "/projects/#{socket.assigns.project.id}")}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> push_patch(to: "/projects/#{socket.assigns.project.id}")}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div
        class="mb-8 py-6 shadow-sm border-b bg-white overflow-hidden"
        style={"border-top: 4px solid #{@project.color}"}
      >
        <article class="w-full xl:max-w-screen-xl md:mx-auto px-4">
          <div class="p-4 w-full flex flex-col md:flex-row md:justify-between gap-4 pb-4 md:items-center">
            <div>
              <h1 class="text-2xl font-medium heading">
                <span class="text-neutral-500 text-base flex items-center gap-2">
                  Project <br />
                </span>
                <%= @project.name %>
                <span class="text-neutral-500 font-mono ml-2">
                  <%= @project.code %>
                </span>
              </h1>
            </div>
            <div class="flex items-center gap-2 flex-wrap">
              <%= button type: "button", to: Routes.export_path(@socket, :create, %{"project_id" => @project.id}),
                  class: "base-button",
                  role: "menuitem",
                  method: :post
                   do %>
                Export
              <% end %>
              <.link
                href={
                  Routes.live_path(@socket, PlatformWeb.MediaLive.Index, %{
                    project_id: @project.id,
                    display: :map
                  })
                }
                class="base-button"
              >
                View Map
              </.link>
              <.link
                href={
                  Routes.live_path(@socket, PlatformWeb.MediaLive.Index, %{
                    project_id: @project.id,
                    display: :cards
                  })
                }
                class="base-button"
              >
                View Incidents
              </.link>
              <%= if Projects.can_edit_project?(@current_user, @project) do %>
                <.link patch={"/projects/#{@project.id}/edit"} class="button ~urge @high">
                  Manage Project
                </.link>
              <% end %>
            </div>
          </div>
        </article>
      </div>
      <article class="w-full xl:max-w-screen-xl md:mx-auto px-4">
        <section class="flex flex-col-reverse lg:flex-row gap-8 max-w-full">
          <div class="lg:w-2/3">
            <div class="border-b border-gray-200 mb-7">
              <nav class="mb-px">
                <div
                  class="text-neutral-600 group inline-flex items-center py-2 px-1 font-medium text-sm"
                  aria-current="page"
                >
                  <Heroicons.clock solid class="text-neutral-400 -ml-0.5 mr-2 h-5 w-5" />
                  <span>Recent Activity</span>
                </div>
              </nav>
            </div>
            <.live_component
              module={PlatformWeb.UpdatesLive.PaginatedMediaUpdateFeed}
              current_user={@current_user}
              restrict_to_project_id={@project.id}
              id="project-updates-feed"
            />
          </div>
          <div class="lg:w-1/3 w-full self-start top-0 sticky min-h-0">
            <div class="border-b border-gray-200 mb-4">
              <nav class="mb-px">
                <div
                  class="text-neutral-600 group inline-flex items-center py-2 px-1 font-medium text-sm"
                  aria-current="page"
                >
                  <Heroicons.squares_2x2 solid class="text-neutral-400 -ml-0.5 mr-2 h-5 w-5" />
                  <span>Project Overview</span>
                </div>
              </nav>
            </div>
            <div>
              <dl class="mt-5 grid w-full grid-cols-1 sm:grid-cols-3 lg:grid-cols-1 gap-4">
                <%= if Enum.empty?(@status_statistics) do %>
                  <div class="text-center mt-8">
                    <Heroicons.chart_pie class="mx-auto h-12 w-12 text-gray-400" />
                    <h3 class="mt-2 text-sm font-medium text-gray-900">No data to display</h3>
                    <p class="mt-1 text-sm text-gray-500">Get started by creating an incident</p>
                  </div>
                <% end %>
                <%= for {status, count} <- @status_statistics |> Enum.sort_by(fn {status, _count} -> Enum.find_index(["Unclaimed", "In Progress", "Help Needed", "Ready for Review", "Completed", "Cancelled"], fn x -> x == status end) || -1 end) do %>
                  <% status_color = Platform.Material.Attribute.attr_color(:status, status) %>
                  <.link
                    href={
                      Routes.live_path(@socket, PlatformWeb.MediaLive.Index, %{
                        attr_status: status,
                        project_id: @project.id,
                        display: :cards
                      })
                    }
                    class="relative overflow-hidden rounded-lg group p-2 hover:bg-neutral-100 transition"
                  >
                    <dt>
                      <div class={"absolute rounded-md p-3 mt-[2px] section @high opacity-50 " <> status_color}>
                        <.attribute_icon name={:status} value={status} />
                      </div>
                      <p class="ml-16 truncate text-sm font-medium text-gray-500">
                        <%= status %>
                      </p>
                    </dt>
                    <dd class="ml-16 flex items-baseline">
                      <p class="text-2xl font-medium text-gray-900">
                        <%= count |> Formatter.format_number() %>
                      </p>
                    </dd>
                  </.link>
                <% end %>
              </dl>
            </div>
          </div>
        </section>
      </article>
      <%= if @live_action == :edit do %>
        <.modal target={} close_confirmation="Your changes will be lost. Are you sure?">
          <div class="mb-8">
            <div class="md:flex justify-between">
              <div>
                <p class="support font-mono uppercase">Manage Project</p>
                <h3 class="sec-head"><%= @project.name %></h3>
              </div>
            </div>
          </div>
          <.live_component
            module={PlatformWeb.ProjectsLive.EditComponent}
            id="edit-project"
            current_user={@current_user}
            project={@project}
          />
        </.modal>
      <% end %>
    </div>
    """
  end
end
