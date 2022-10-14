defmodule PlatformWeb.MediaLive.PaginatedMediaList do
  use PlatformWeb, :live_component
  alias Platform.Material

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
    ~H"""
    <section>
      <div class="grid gap-4 grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 search-highlighting">
        <%= for media <- @media do %>
          <.media_card media={media} current_user={@current_user} />
        <% end %>
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
