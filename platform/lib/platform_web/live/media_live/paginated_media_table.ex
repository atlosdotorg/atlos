defmodule PlatformWeb.MediaLive.PaginatedMediaTable do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Material.Attribute

  def update(%{query_params: params, current_user: _user} = assigns, socket) do
    hydrated_socket = socket |> assign(assigns)

    results = search_media(hydrated_socket, Material.MediaSearch.changeset(params), limit: 250)

    {:ok,
     hydrated_socket
     |> assign(:results, results)
     |> assign(:media, results.entries)}
  end

  def handle_event("load_more", _params, socket) do
    cursor_after = socket.assigns.results.metadata.after

    results =
      search_media(socket, Material.MediaSearch.changeset(socket.assigns.query_params),
        after: cursor_after,
        limit: 1000
      )

    new_socket =
      socket
      |> assign(:results, results)
      |> assign(:media, socket.assigns.media ++ results.entries)

    {:noreply, new_socket}
  end

  defp search_media(socket, c, pagination_opts \\ []) do
    {query, pagination_options} = Material.MediaSearch.search_query(c)

    query
    |> Material.MediaSearch.filter_viewable(socket.assigns.current_user)
    |> Material.query_media_paginated(Keyword.merge(pagination_options, pagination_opts))
  end

  def render(assigns) do
    attributes = Attribute.active_attributes() |> Enum.filter(&is_nil(&1.parent))

    ~H"""
    <section class="max-w-full">
      <%= if length(@media) == 0 do %>
        <.no_media_results />
      <% else %>
        <div class="min-w-full overflow-x-auto -mx-8 rounded-lg">
          <div class="min-w-full inline-block py-2 align-middle rounded-lg">
            <div class="shadow-sm rounded ring-1 ring-black ring-opacity-5">
              <table class="min-w-full border-separate" style="border-spacing: 0">
                <thead class="bg-gray-100 whitespace-nowrap">
                  <tr>
                    <th
                      scope="col"
                      class="sticky top-0 z-100 border-b border-gray-300 bg-gray-100 bg-opacity-75 px-4 py-4 font-medium text-sm text-left"
                    >
                      <span class="sr-only">Slug</span>
                    </th>
                    <th
                      scope="col"
                      class="sticky top-0 z-100 border-b border-gray-300 bg-gray-100 bg-opacity-75 px-4 py-4 font-medium text-sm text-left"
                    >
                      Updated
                    </th>
                    <%= for attr <- attributes do %>
                      <th
                        scope="col"
                        class="sticky top-0 z-100 border-b border-gray-300 bg-gray-100 bg-opacity-75 px-4 py-4 font-medium text-sm text-left"
                      >
                        <%= attr.label %>
                      </th>
                    <% end %>
                    <th
                      scope="col"
                      class="sticky top-0 z-100 border-b border-gray-300 bg-gray-100 bg-opacity-75 px-4 py-4 font-medium text-sm text-left"
                    >
                      Sources
                    </th>
                    <th
                      scope="col"
                      class="sticky top-0 z-10 border-b border-gray-300 bg-gray-100 bg-opacity-75 py-3.5 pr-4 pl-3 backdrop-blur backdrop-filter sm:pr-6 lg:pr-8"
                    >
                      <span class="sr-only">Edit</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white">
                  <%= for media <- @media do %>
                    <tr class="hover:bg-gray-50">
                      <td class="font-mono whitespace-nowrap border-b border-gray-200 p-0 h-10">
                        <.link
                          href={"/incidents/#{media.slug}"}
                          class="text-button text-neutral-500 text-sm ml-4"
                        >
                          <%= media.slug %>
                        </.link>
                      </td>
                      <td class="whitespace-nowrap border-b border-gray-200 text-sm text-neutral-600">
                        <div class="ml-4">
                          <.rel_time time={media.updated_at} />
                        </div>
                      </td>
                      <%= for attr <- attributes do %>
                        <td class="border-b hover:bg-neutral-100 cursor-pointer p-0">
                          <div class="text-sm text-gray-900 px-4 overflow-hidden h-6 max-w-[36rem]">
                            <.attr_display_compact
                              attr={attr}
                              media={media}
                              updates={media.updates}
                              socket={@socket}
                              current_user={@current_user}
                            />
                          </div>
                        </td>
                      <% end %>
                      <td class="border-b hover:bg-neutral-100 text-sm p-0">
                        <div class="w-48 overflow-hidden">
                          <% versions =
                            media.versions
                            |> Enum.filter(&Material.MediaVersion.can_user_view(&1, @current_user)) %>
                          <.popover>
                            <:display>
                              <div class="break-all flex flex-col gap-px text-neutral-600">
                                <%= for version <- versions do %>
                                  <a
                                    href={version.source_url}
                                    title={version.source_url}
                                    rel="nofollow"
                                    target="_blank"
                                    class="block"
                                  >
                                    <.url_icon url={version.source_url} class="h-4 w-4 inline" />
                                    <%= version.source_url %>
                                  </a>
                                <% end %>
                              </div>
                            </:display>
                            <div class="max-w-48">
                              <%= for version <- versions do %>
                                <a
                                  href={version.source_url}
                                  title={version.source_url}
                                  rel="nofollow"
                                  target="_blank"
                                >
                                  <.url_icon url={version.source_url} class="h-4 w-4 inline" />
                                  <span class="hidden"><%= version.source_url %></span>
                                </a>
                              <% end %>
                            </div>
                          </.popover>
                        </div>
                      </td>
                      <td class="relative whitespace-nowrap break-all border-b border-gray-200 pr-4 pl-3 text-right text-sm font-medium sm:pr-6 lg:pr-8">
                        <.link href={"/incidents/#{media.slug}"} class="text-button">
                          View &rarr;<span class="sr-only">, <%= media.slug %></span>
                        </.link>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      <% end %>
      <div class="mx-auto mt-8 text-center text-xs">
        <%= if !is_nil(@results.metadata.after) do %>
          <button
            type="button"
            class="text-button"
            phx-click="load_more"
            phx-target={@myself}
            phx-disable-with="Loading..."
          >
            Load More
          </button>
        <% end %>
      </div>
    </section>
    """
  end
end
