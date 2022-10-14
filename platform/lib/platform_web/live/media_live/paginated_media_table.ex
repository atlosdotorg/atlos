defmodule PlatformWeb.MediaLive.PaginatedMediaTable do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Material.Attribute

  def update(%{query_params: params, current_user: user} = assigns, socket) do
    hydrated_socket = socket |> assign(assigns)

    # Noah: would be cool if when you hover over media, you get a preview

    results = search_media(hydrated_socket, Material.MediaSearch.changeset(params), limit: 250)

    {:ok,
     hydrated_socket
     |> assign(:results, results)
     |> assign(:editing, nil)
     |> assign(:current_user, user)
     |> assign(:media, results.entries)}
  end

  def handle_event("load_more", _params, socket) do
    cursor_after = socket.assigns.results.metadata.after

    results =
      search_media(socket, Material.MediaSearch.changeset(socket.assigns.query_params),
        after: cursor_after,
        limit: 100
      )

    new_socket =
      socket
      |> assign(:results, results)
      |> assign(:media, socket.assigns.media ++ results.entries)

    {:noreply, new_socket}
  end

  def handle_event(
        "edit_attribute",
        %{"attribute" => attr_name, "media-id" => media_id} = _params,
        socket
      ) do
    {id, ""} = Integer.parse(media_id) |> dbg()

    {:noreply,
     socket
     |> assign(
       :editing,
       {Enum.find(socket.assigns.media, &(&1.id == id)), attr_name}
     )}
  end

  def handle_info(
        {:end_attribute_edit, updated_media},
        socket
      ) do
    if is_nil(updated_media) do
      socket
    else
      {:noreply,
       socket
       |> assign(
         :media,
         Enum.map(socket.assigns.media, fn m ->
           if m.id == updated_media.id, do: updated_media, else: m
         end)
       )}
    end
  end

  defp search_media(socket, c, pagination_opts \\ []) do
    {query, pagination_options} = Material.MediaSearch.search_query(c)

    query
    |> Material.MediaSearch.filter_viewable(socket.assigns.current_user)
    |> Material.query_media_paginated(Keyword.merge(pagination_options, pagination_opts))
  end

  def render(assigns) do
    attributes = Attribute.active_attributes() |> Enum.filter(&is_nil(&1.parent))

    media = assigns.media
    source_cols = Enum.max(media |> Enum.map(&length(&1.versions)))

    ~H"""
    <section class="max-w-full">
      <%= if length(@media) == 0 do %>
        <.no_media_results />
      <% else %>
        <div class="min-w-full overflow-x-auto -mx-8 rounded-lg">
          <div class="min-w-full inline-block py-2 align-middle rounded-lg">
            <div class="shadow-sm rounded ring-1 ring-black ring-opacity-5">
              <table class="min-w-full relative border-separate" style="border-spacing: 0">
                <thead class="bg-gray-100 whitespace-nowrap">
                  <tr>
                    <th
                      scope="col"
                      class="sticky left-0 z-[99] top-0 border-b border-gray-300 bg-gray-100 bg-opacity-75 px-4 py-4 font-medium text-sm text-left"
                    >
                      <span class="sr-only">Slug</span>
                    </th>
                    <th
                      scope="col"
                      class="sticky z-[100] top-0 border-b border-gray-300 bg-gray-100 bg-opacity-75 px-4 py-4 font-medium text-sm text-left"
                    >
                      Updated
                    </th>
                    <%= for attr <- attributes do %>
                      <th
                        scope="col"
                        class="sticky z-[100] top-0 border-b border-gray-300 bg-gray-100 bg-opacity-75 px-4 py-4 font-medium text-sm text-left"
                      >
                        <%= attr.label %>
                      </th>
                    <% end %>
                    <%= for idx <- 0..source_cols do %>
                      <th
                        scope="col"
                        class="sticky z-[100] top-0 border-b border-gray-300 bg-gray-100 bg-opacity-75 px-4 py-4 font-medium text-sm text-left"
                      >
                        Source <%= idx + 1 %>
                      </th>
                    <% end %>
                  </tr>
                </thead>
                <tbody class="bg-white">
                  <%= for media <- @media do %>
                    <tr class="hover:bg-gray-50">
                      <td class="sticky left-0 z-[100] bg-white group-hover:bg-neutral-50 px-4 shadow font-mono whitespace-nowrap border-b border-gray-200 h-10">
                        <.link href={"/incidents/#{media.slug}"} class="text-button text-sm">
                          <%= media.slug %>
                        </.link>
                      </td>
                      <td class="border-b hover:bg-neutral-100 cursor-pointer p-0 text-sm text-neutral-600">
                        <div class="ml-4 flex w-[7rem] relative z-0">
                          <div class="flex-shrink-0 w-5 mr-1">
                            <.user_stack users={media.updates |> Enum.take(1) |> Enum.map(& &1.user)} />
                          </div>
                          <div class="flex-shrink-0">
                            <.rel_time time={media.updated_at} />
                          </div>
                        </div>
                      </td>
                      <%= for attr <- attributes do %>
                        <td class="border-b hover:bg-neutral-100 cursor-pointer p-0">
                          <div
                            class="text-sm text-gray-900 px-4 overflow-hidden h-6 max-w-[36rem]"
                            phx-click="edit_attribute"
                            phx-value-attribute={attr.name}
                            phx-value-media-id={media.id}
                            phx-target={@myself}
                          >
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
                      <% versions =
                        media.versions
                        |> Enum.filter(&Material.MediaVersion.can_user_view(&1, @current_user)) %>
                      <%= for idx <- 0..source_cols do %>
                        <td class="border-b hover:bg-neutral-100 cursor-pointer p-0">
                          <div class="text-sm text-gray-900 px-4 truncate h-6 w-[12rem]">
                            <% version = Enum.at(versions, idx) %>
                            <%= if not is_nil(version) do %>
                              <p>
                                <a
                                  href={version.source_url}
                                  target="_blank"
                                  rel="nofollow"
                                  class="truncate"
                                >
                                  <.url_icon url={version.source_url} class="h-4 w-4 inline mb-px" />
                                  <%= version.source_url %>
                                </a>
                              </p>
                            <% else %>
                              <span class="text-neutral-400">
                                &mdash;
                              </span>
                            <% end %>
                          </div>
                        </td>
                      <% end %>
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
      <%= with {media, attribute_name} <- @editing do %>
        <.live_component
          module={PlatformWeb.MediaLive.EditAttribute}
          id="edit-attribute"
          media={media}
          name={attribute_name}
          target={self()}
          current_user={@current_user}
        />
      <% end %>
    </section>
    """
  end
end
