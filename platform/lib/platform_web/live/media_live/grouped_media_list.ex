defmodule PlatformWeb.MediaLive.GroupedMediaList do
  use PlatformWeb, :live_component
  alias Platform.Material

  def groups(%Platform.Accounts.User{} = _user) do
    [
      {"Unclaimed", %{"attr_status" => ["Unclaimed"]}},
      {"In Progress", %{"attr_status" => ["In Progress"]}},
      {"Help Needed", %{"attr_status" => ["Help Needed"]}},
      {"Ready for Review", %{"attr_status" => ["Ready for Review"]}}
    ]
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)

    {:ok,
     socket
     |> assign(
       :groups,
       Enum.map(groups(assigns.current_user), fn {label, params} ->
         combined_params = Map.merge(assigns.params, params)

         {label, combined_params,
          search_media(socket, Material.MediaSearch.changeset(combined_params), limit: 4).entries}
       end)
     )}
  end

  defp search_media(socket, c, pagination_opts) do
    {query, pagination_options} = Material.MediaSearch.search_query(c)

    query
    |> Material.MediaSearch.filter_viewable(socket.assigns.current_user)
    |> Material.query_media_paginated(
      Keyword.merge(Keyword.merge(pagination_options, pagination_opts),
        for_user: socket.assigns.current_user
      )
    )
  end

  def render(assigns) do
    ~H"""
    <section class="flex flex-col mx-auto gap-16 mb-16 w-full">
      <%= for {label, params, media} <- @groups do %>
        <% link = Routes.live_path(@socket, PlatformWeb.MediaLive.Index, params) %>
        <div>
          <div>
            <div class="mb-4 md:flex md:justify-between md:items-center">
              <.link
                navigate={link}
                class={"block text-2xl font-medium heading " <> Platform.Material.Attribute.attr_color(:status, label)}
              >
                <%= label %>
              </.link>
              <.link
                class="block sm:mt-0 font-medium text-neutral-600 hover:text-neutral-800"
                navigate={link}
              >
                All
                <span class={"badge text-sm mb-px " <> Platform.Material.Attribute.attr_color(:status, label)}>
                  <%= label %>
                </span>
                incidents &rarr;
              </.link>
            </div>
            <%= if Enum.empty?(media) do %>
              <div class="text-center py-12 rounded border-neutral-300 w-full border border-dashed w-full border-2">
                <svg
                  class="mx-auto h-16 w-16 text-gray-400"
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
                <h3 class="mt-2 font-medium text-gray-900">No incidents</h3>
              </div>
            <% else %>
              <div class="grid gap-4 grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 sm:grid-rows-1">
                <%= for m <- media do %>
                  <.media_card media={m} current_user={@current_user} />
                <% end %>
              </div>
              <div class="my-2 text-sm"></div>
            <% end %>
          </div>
        </div>
      <% end %>
    </section>
    """
  end
end
