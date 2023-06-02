defmodule PlatformWeb.ProjectsLive.Show do
  use PlatformWeb, :live_view

  alias PlatformWeb.Errors.NotFound
  alias Platform.Material.MediaSearch
  alias Platform.Projects
  alias Platform.Material
  alias Platform.Permissions

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    project = Projects.get_project!(id)

    if !Permissions.can_view_project?(socket.assigns.current_user, project) do
      raise NotFound, "Not found"
    end

    if socket.assigns.live_action == :manage and
         !Permissions.can_edit_project_metadata?(socket.assigns.current_user, project) do
      raise NotFound, "Not found"
    end

    {query, _} = MediaSearch.search_query(MediaSearch.changeset(%{"project_id" => id}))
    query = MediaSearch.filter_viewable(query, socket.assigns.current_user)

    membership_id =
      Platform.Projects.get_project_membership_by_user_and_project(
        socket.assigns.current_user,
        project
      ).id

    if socket.assigns.current_user.active_project_membership_id !=
         membership_id do
      Platform.Accounts.update_user_preferences(socket.assigns.current_user, %{
        active_project_membership_id: membership_id
      })
    end

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
     |> assign(
       :status_statistics,
       Material.status_overview_statistics(
         project_id: project.id,
         for_user: socket.assigns.current_user
       )
     )}
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
          <div class="pt-4 w-full flex flex-col md:flex-row md:justify-between gap-4">
            <div>
              <p class="text-neutral-500 text-sm font-base flex items-center gap-2">
                Project
              </p>
              <h1 class="text-3xl font-semibold heading">
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
              <div class="text-neutral-500 prose mt-6 leading-snug">
                <%= @project.description |> Platform.Utils.render_markdown() |> raw() %>
              </div>
            </div>
            <div class="flex self-start mt-4 gap-2 flex-wrap">
              <%= button type: "button", to: Routes.export_path(@socket, :create, %{"project_id" => @project.id}),
                  class: "base-button",
                  role: "menuitem",
                  method: :post
                   do %>
                Export
              <% end %>
              <%= if Permissions.can_edit_project_metadata?(@current_user, @project) do %>
                <.link href={"/new?project_id=#{@project.id}"} class="button ~urge @high">
                  New Incident
                </.link>
              <% end %>
            </div>
          </div>
          <nav class="flex space-x-8 mt-8 overflow-x-auto" aria-label="Tabs">
            <% inactive_classes =
              "transition-all border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 group inline-flex items-center py-4 px-1 border-b-2 font-medium text-sm" %>
            <% active_classes =
              "transition-all border-urge-500 text-urge-600 group inline-flex items-center py-4 px-1 border-b-2 font-medium text-sm" %>

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
              patch={"/projects/#{@project.id}/queue"}
              class={if @live_action == :queue, do: active_classes, else: inactive_classes}
            >
              <Heroicons.queue_list mini class="opacity-75 -ml-0.5 mr-2 h-5 w-5" />
              <span>Queue</span>
            </.link>

            <%= if Permissions.can_edit_project_metadata?(@current_user, @project) do %>
              <.link
                patch={"/projects/#{@project.id}/edit"}
                class={if @live_action == :edit, do: active_classes, else: inactive_classes}
              >
                <Heroicons.cog_6_tooth mini class="opacity-75 -ml-0.5 mr-2 h-5 w-5" />
                <span>Manage</span>
              </.link>
            <% end %>

            <%= if feature_available?(:project_access_controls) do %>
              <.link
                patch={"/projects/#{@project.id}/members"}
                class={if @live_action == :members, do: active_classes, else: inactive_classes}
              >
                <Heroicons.user_circle mini class="opacity-75 -ml-0.5 mr-2 h-5 w-5" />
                <span>Members</span>
              </.link>
            <% end %>

            <%= if Permissions.can_view_project_deleted_media?(@current_user, @project) do %>
              <.link
                patch={"/projects/#{@project.id}/deleted"}
                class={if @live_action == :deleted, do: active_classes, else: inactive_classes}
              >
                <Heroicons.trash mini class="opacity-75 -ml-0.5 mr-2 h-5 w-5" />
                <span>Deleted</span>
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
                  <% else %>
                    <%= for {status, count} <- @status_statistics |> Enum.sort_by(fn {status, _count} -> Enum.find_index(["Unclaimed", "In Progress", "Help Needed", "Ready for Review", "Completed", "Cancelled"], fn x -> x == status end) || -1 end) do %>
                      <% status_color = Platform.Material.Attribute.attr_color(:status, status) %>
                      <.link
                        href={
                          Routes.live_path(@socket, PlatformWeb.MediaLive.Index, %{
                            attr_status: [status],
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
                    <.link patch={"/projects/#{@project.id}/queue"} class="text-button p-2">
                      View in queue &rarr;
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
                color: @project.color
              }
            end) %>
          <div class="w-full h-full">
            <.map_events map_data={map_data} />
          </div>
        <% end %>
        <%= if @live_action == :queue do %>
          <.live_component
            module={PlatformWeb.MediaLive.GroupedMediaList}
            id="project-queue"
            current_user={@current_user}
            params={%{"project_id" => @project.id}}
          />
        <% end %>
        <%= if @live_action == :edit do %>
          <.live_component
            module={PlatformWeb.ProjectsLive.EditComponent}
            id="edit-project"
            current_user={@current_user}
            project={@project}
          />
          <hr />
          <.live_component
            module={PlatformWeb.ProjectsLive.BulkUploadLive}
            id="bulk-upload"
            current_user={@current_user}
            project={@project}
          />
        <% end %>
        <%= if @live_action == :members and feature_available?(:project_access_controls) do %>
          <.live_component
            module={PlatformWeb.ProjectsLive.MembersComponent}
            id="project-members"
            current_user={@current_user}
            project={@project}
          />
        <% end %>
        <%= if @live_action == :deleted and Permissions.can_view_project_deleted_media?(@current_user, @project) do %>
          <.live_component
            module={PlatformWeb.MediaLive.PaginatedMediaList}
            id="deleted-media-list"
            current_user={@current_user}
            query_params={%{deleted: true, project_id: @project.id}}
          />
        <% end %>
      </article>
    </div>
    """
  end
end
