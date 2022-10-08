defmodule PlatformWeb.MediaLive.PaginatedMediaTable do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Material.Attribute

  def update(%{query_params: params, current_user: _user} = assigns, socket) do
    hydrated_socket = socket |> assign(assigns)

    results = search_media(hydrated_socket, Material.MediaSearch.changeset(params))

    {:ok,
     hydrated_socket
     |> assign(:results, results)
     |> assign(:media, results.entries)}
  end

  def handle_event("load_more", _params, socket) do
    cursor_after = socket.assigns.results.metadata.after

    results =
      search_media(socket, Material.MediaSearch.changeset(socket.assigns.query_params),
        after: cursor_after
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
    attributes = Attribute.active_attributes()

    ~H"""
    <section>
      <div class="mt-8 flex flex-col">
        <div class="-my-2 -mx-4 sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle">
            <div class="shadow-sm ring-1 ring-black ring-opacity-5">
              <table class="min-w-full border-separate" style="border-spacing: 0">
                <thead class="bg-gray-50">
                  <tr>
                    <%= for attr <- attributes do %>
                      <th
                        scope="col"
                        class="sticky top-0 z-10 border-b border-gray-300 bg-gray-50 bg-opacity-75 py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 backdrop-blur backdrop-filter sm:pl-6 lg:pl-8"
                      >
                        <%= attr.label %>
                      </th>
                    <% end %>
                    <th
                      scope="col"
                      class="sticky top-0 z-10 border-b border-gray-300 bg-gray-50 bg-opacity-75 py-3.5 pr-4 pl-3 backdrop-blur backdrop-filter sm:pr-6 lg:pr-8"
                    >
                      <span class="sr-only">Edit</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white">
                  <%= for media <- @media do %>
                    <tr>
                      <%= for attr <- attributes do %>
                        <td class="whitespace-nowrap border-b border-gray-200 py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6 lg:pl-8">
                          <.attr_display_compact
                            attr={attr}
                            media={media}
                            updates={media.updates}
                            socket={@socket}
                            current_user={@current_user}
                          />
                        </td>
                      <% end %>
                      <td class="relative whitespace-nowrap border-b border-gray-200 py-4 pr-4 pl-3 text-right text-sm font-medium sm:pr-6 lg:pr-8">
                        <.link href={"/incidents/#{media.slug}"} class="text-button">
                          View &rarr;<span class="sr-only">, <%= media.slug %></span>
                        </.link>
                      </td>
                    </tr>
                  <% end %>
                  <!-- More people... -->
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
      <%= if length(@media) == 0 do %>
        <.no_media_results />
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
