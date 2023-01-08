defmodule PlatformWeb.ProjectsLive.Show do
  use PlatformWeb, :live_view

  alias Platform.Material.MediaSearch
  alias Platform.Projects
  alias Platform.Material

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    project = Projects.get_project!(id)

    {query, _} =
      MediaSearch.search_query(MediaSearch.changeset(%{"project_id" => id}))
      |> MediaSearch.filter_viewable(socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:title, project.name)
     |> assign(:project, project)
     |> assign(:active_project, project)
     |> assign(
       :media,
       if(socket.assigns.live_action == :map,
         do: Material.query_media(query)
       )
     )
     |> assign(:full_width, true)
     |> assign(:status_statistics, Material.status_overview_statistics(project_id: project.id))}
  end

  def handle_info({:project_saved, project}, socket) do
    {:noreply, socket |> put_flash(:info, "Changes saved.") |> assign(:project, project)}
  end

  def handle_info({:project_deleted, _project}, socket) do
    {:noreply,
     socket |> push_redirect(to: "/projects") |> put_flash(:info, "Project deleted successfully.")}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-8 pt-6 shadow-sm border-b bg-white overflow-hidden relative z-[1000]">
        <article class="w-full h-full xl:max-w-screen-xl md:mx-auto px-4">
          <div class="pt-4 w-full flex flex-col md:flex-row md:justify-between gap-4 md:items-center">
            <div>
              <p class="text-neutral-500 text-sm font-base flex items-center gap-2">
                Project
              </p>
              <h1 class="text-3xl font-medium heading">
                <div class="inline-flex items-center">
                  <%= @project.name %>
                  <span style={"color: #{@project.color}"}>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 20 20"
                      fill="currentColor"
                      class="w-5 h-5 ml-1"
                    >
                      <circle cx="10" cy="10" r="8" />
                    </svg>
                  </span>
                </div>
              </h1>
              <div class="text-neutral-500 prose mt-6">
                <%= @project.description |> Platform.Utils.render_markdown() |> raw() %>
              </div>
            </div>
            <div class="flex items-center gap-2 flex-wrap">
              <%= button type: "button", to: Routes.export_path(@socket, :create, %{"project_id" => @project.id}),
                  class: "base-button",
                  role: "menuitem",
                  method: :post
                   do %>
                Export
              <% end %>
              <%= if Projects.can_edit_project?(@current_user, @project) do %>
                <.link href={"/new?project_id=#{@project.id}"} class="button ~urge @high">
                  + New Incident
                </.link>
              <% end %>
            </div>
          </div>
          <nav class="flex space-x-8 mt-8 overflow-x-auto" aria-label="Tabs">
            <% inactive_classes =
              "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 group inline-flex items-center py-4 px-1 border-b-2 font-medium text-sm" %>
            <% active_classes =
              "border-urge-500 text-urge-600 group inline-flex items-center py-4 px-1 border-b-2 font-medium text-sm" %>

            <.link
              patch={"/projects/#{@project.id}"}
              class={if @live_action == :overview, do: active_classes, else: inactive_classes}
            >
              <Heroicons.chart_bar mini class="opacity-75 -ml-0.5 mr-2 h-5 w-5" />
              <span>Overview</span>
            </.link>

            <.link
              patch={"/projects/#{@project.id}/map"}
              class={if @live_action == :map, do: active_classes, else: inactive_classes}
            >
              <Heroicons.map mini class="opacity-75 -ml-0.5 mr-2 h-5 w-5" />
              <span>Map</span>
            </.link>

            <.link
              patch={"/projects/#{@project.id}/incidents"}
              class={if @live_action == :incidents, do: active_classes, else: inactive_classes}
            >
              <Heroicons.rectangle_stack mini class="opacity-75 -ml-0.5 mr-2 h-5 w-5" />
              <span>Incidents</span>
            </.link>

            <%= if Projects.can_edit_project?(@current_user, @project) do %>
              <.link
                patch={"/projects/#{@project.id}/edit"}
                class={if @live_action == :edit, do: active_classes, else: inactive_classes}
              >
                <Heroicons.cog_6_tooth mini class="opacity-75 -ml-0.5 mr-2 h-5 w-5" />
                <span>Manage</span>
              </.link>
            <% end %>

            <.link
              href={
                Routes.live_path(@socket, PlatformWeb.MediaLive.Index, %{
                  project_id: @project.id,
                  display: :cards
                })
              }
              class={inactive_classes}
            >
              <Heroicons.magnifying_glass mini class="opacity-75 -ml-0.5 mr-2 h-5 w-5" />
              <span>Search&nbsp;&rarr;</span>
            </.link>
          </nav>
        </article>
      </div>
      <article class="w-full xl:max-w-screen-xl md:mx-auto px-4">
        <%= if @live_action == :overview do %>
          <section class="flex flex-col-reverse h-full lg:flex-row gap-8 max-w-full md:divide-x">
            <div class="lg:w-2/3">
              <.live_component
                module={PlatformWeb.UpdatesLive.PaginatedMediaUpdateFeed}
                current_user={@current_user}
                restrict_to_project_id={@project.id}
                id="project-updates-feed"
              />
            </div>
            <div class="lg:w-1/3 w-full top-0 sticky min-h-0 md:pl-8">
              <div>
                <dl class="grid w-full grid-cols-1 sm:grid-cols-3 lg:grid-cols-1 gap-4">
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
        <% end %>
        <%= if @live_action == :map do %>
          <% map_data =
            @media
            |> Enum.filter(&(not is_nil(&1.attr_geolocation)))
            |> Enum.map(fn item ->
              {lon, lat} = item.attr_geolocation.coordinates

              %{
                slug: item.slug,
                # Stringify to avoid floating point issues
                lat: "#{lat}",
                lon: "#{lon}",
                type: Material.get_media_organization_type(item)
              }
            end) %>
          <div class="w-full h-full">
            <map-events
              lat="35"
              lon="35"
              zoom="3"
              id="map_events"
              container-id="map_events_container"
              data={Jason.encode!(map_data)}
            />
            <section
              class="fixed h-screen w-screen left-0 top-0 bottom-0"
              id="map"
              phx-update="ignore"
            >
              <map-container id="map_events_container" />
            </section>
          </div>
        <% end %>
        <%= if @live_action == :incidents do %>
          <.live_component
            module={PlatformWeb.MediaLive.PaginatedMediaList}
            id="media-list"
            current_user={@current_user}
            query_params={%{"project_id" => @project.id}}
          />
        <% end %>
        <%= if @live_action == :edit do %>
          <div class="max-w-prose">
            <.live_component
              module={PlatformWeb.ProjectsLive.EditComponent}
              id="edit-project"
              current_user={@current_user}
              project={@project}
            />
          </div>
        <% end %>
      </article>
    </div>
    """
  end
end
