defmodule PlatformWeb.SearchLive.SearchComponent do
  use PlatformWeb, :live_component

  alias Platform.GlobalSearch
  alias Phoenix.LiveView.JS

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:active, false)

    {:ok,
     socket
     |> assign_results("")}
  end

  def handle_event("open_modal_keybind", %{"key" => "k", "ctrlKey" => true}, socket) do
    {:noreply, socket |> assign(:active, true)}
  end

  def handle_event("open_modal_keybind", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("open_modal", _params, socket) do
    {:noreply, socket |> assign(:active, true)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> assign(:active, false)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign_results(query)}
  end

  defp assign_results(socket, query) do
    results = GlobalSearch.perform_search(query, socket.assigns.current_user)

    # We must assign an ordinal to each result so that we can use it in the
    # template to determine which result is selected. There must be only one instance
    # of each ordinal across all result types.
    result_order = [
      :users,
      :media,
      :media_versions,
      :projects,
      :updates
    ]

    results_with_ordinals =
      Enum.map(results, fn {result_type, values} ->
        result_index = Enum.find_index(result_order, fn x -> x == result_type end)

        total_count_before =
          Enum.sum(
            Enum.take(result_order, result_index)
            |> Enum.map(fn x -> Enum.count(Map.get(results, x)) end)
          )

        {result_type, Enum.with_index(values, total_count_before)}
      end)
      |> Enum.into(%{})

    socket
    |> assign(:query, query)
    |> assign(:results, results_with_ordinals)
    |> assign(
      :has_any_results,
      Enum.any?(results, fn {_, results} -> not Enum.empty?(results) end)
    )
    |> assign(
      :total_results,
      Enum.sum(Enum.map(results, fn {_, results} -> Enum.count(results) end))
    )
  end

  def render(assigns) do
    ~H"""
    <div
      x-data="{selected: 0, lastKeyChangeTime: 0}"
      x-ref="root"
      class="w-full flex flex-col items-center"
      x-on:keydown.down={"selected++; lastKeyChangeTime = new Date().getTime(); $refs.root.querySelector(`[data-selector-index='${selected % #{@total_results}}']`).scrollIntoView()"}
      x-on:keydown.up={"selected--; lastKeyChangeTime = new Date().getTime(); $refs.root.querySelector(`[data-selector-index='${selected % #{@total_results}}']`).scrollIntoView()"}
      x-on:keydown.enter={"$refs.root.querySelector(`[data-selector-index='${selected % #{@total_results}}']`).click()"}
    >
      <button type="button" phx-click="open_modal" phx-target={@myself} class="w-full">
        <%= render_slot(@inner_block) %>
      </button>
      <span phx-window-keydown="open_modal_keybind" phx-key="k" phx-target={@myself} />
      <span phx-window-keydown="close_modal" phx-key="escape" phx-target={@myself} />
      <div :if={@active} class="fixed z-10 w-screen h-screen" role="dialog" aria-modal="true">
        <div
          class="fixed inset-0 bg-gray-800 bg-opacity-50 hidden"
          phx-mounted={
            JS.show(transition: {"ease-out duration-100", "opacity-0", "opacity-100"}, time: 100)
          }
          phx-remove={
            JS.hide(transition: {"ease-in duration-50", "opacity-100", "opacity-0"}, time: 50)
          }
          phx-click="close_modal"
          phx-target={@myself}
        >
        </div>

        <div
          class="fixed inset-0 z-10 w-screen overflow-y-auto p-4 sm:p-6 md:p-20"
          phx-target={@myself}
        >
          <div
            class="mx-auto max-w-xl lg:max-w-2xl transform divide-y divide-gray-100 overflow-hidden rounded-xl bg-white shadow-2xl ring-1 ring-black ring-opacity-5 hidden"
            phx-mounted={
              JS.show(
                transition: {"ease-out duration-100", "opacity-0 scale-95", "opacity-100 scale-100"},
                time: 100
              )
            }
            phx-remove={
              JS.hide(
                transition: {"ease-in duration-50", "opacity-100 scale-100", "opacity-0 scale-95"},
                time: 50
              )
            }
            phx-click-away="close_modal"
            phx-target={@myself}
          >
            <div class="relative">
              <svg
                class="pointer-events-none absolute left-4 top-3.5 h-5 w-5 text-gray-400"
                viewBox="0 0 20 20"
                fill="currentColor"
                aria-hidden="true"
              >
                <path
                  fill-rule="evenodd"
                  d="M9 3.5a5.5 5.5 0 100 11 5.5 5.5 0 000-11zM2 9a7 7 0 1112.452 4.391l3.328 3.329a.75.75 0 11-1.06 1.06l-3.329-3.328A7 7 0 012 9z"
                  clip-rule="evenodd"
                />
              </svg>
              <form phx-change="search" phx-submit="search" phx-target={@myself}>
                <input
                  type="text"
                  phx-debounce="200"
                  class="h-12 w-full border-0 bg-transparent pl-11 pr-4 text-gray-900 placeholder:text-gray-400 focus:ring-0 sm:text-sm"
                  placeholder="Search..."
                  role="combobox"
                  aria-expanded="false"
                  aria-controls="options"
                  name="query"
                  phx-mounted={JS.focus() |> JS.dispatch("select")}
                  value={@query}
                />
              </form>
            </div>
            <ul
              :if={@has_any_results}
              class="max-h-[70vh] scroll-smooth transform-gpu scroll-py-10 scroll-pb-2 space-y-4 overflow-y-auto p-4 pb-2"
              id="options"
              role="listbox"
            >
              <li :if={not Enum.empty?(@results.users)}>
                <h2 class="text-xs font-medium text-neutral-500">Users</h2>
                <ul class="-mx-4 mt-2 text-sm text-neutral-700">
                  <%= for {user, idx} <- @results.users do %>
                    <.link navigate={"/profile/#{user.username}"} class="cursor-pointer">
                      <li
                        id={user.id}
                        class="group flex transition rounded mx-2 ease-in-out duration-100 select-none items-center px-2 py-2"
                        x-bind:class={"#{idx} === (selected % #{@total_results}) ? 'bg-neutral-200' : 'bg-white'"}
                        x-on:mouseenter={"if (new Date().getTime() - lastKeyChangeTime > 500) { selected = #{idx} }"}
                        role="option"
                        tabindex="-1"
                        data-selector-index={idx}
                      >
                        <img
                          src={Platform.Accounts.get_profile_photo_path(user)}
                          alt=""
                          class="h-6 w-6 flex-none rounded-full"
                        />
                        <span class="ml-3 flex-auto truncate font-medium"><%= user.username %></span>
                      </li>
                    </.link>
                  <% end %>
                </ul>
              </li>
              <li :if={not Enum.empty?(@results.media)}>
                <h2 class="text-xs font-medium text-neutral-500">Media</h2>
                <ul class="-mx-4 mt-2 text-sm text-neutral-700">
                  <%= for {item, idx} <- @results.media do %>
                    <.link navigate={"/incidents/#{item.slug}"} class="cursor-pointer">
                      <li
                        id={item.id}
                        class="group flex transition rounded mx-2 ease-in-out duration-100 select-none items-center px-2 py-2"
                        x-bind:class={"#{idx} === (selected % #{@total_results}) ? 'bg-neutral-200' : 'bg-white'"}
                        x-on:mouseenter={"if (new Date().getTime() - lastKeyChangeTime > 500) { selected = #{idx} }"}
                        role="option"
                        tabindex="-1"
                        data-selector-index={idx}
                      >
                        <.media_line_preview_compact_unlinked media={item} />
                      </li>
                    </.link>
                  <% end %>
                </ul>
              </li>
              <li :if={not Enum.empty?(@results.media_versions)}>
                <h2 class="text-xs font-medium text-neutral-500">Source Material</h2>
                <ul class="-mx-4 mt-2 text-sm text-neutral-700">
                  <%= for {item, idx} <- @results.media_versions do %>
                    <.link
                      navigate={"/incidents/#{item.media.slug}/detail/#{item.scoped_id}"}
                      class="cursor-pointer"
                    >
                      <li
                        id={item.id}
                        class="group flex transition rounded mx-2 ease-in-out duration-100 select-none items-center px-2 py-2"
                        x-bind:class={"#{idx} === (selected % #{@total_results}) ? 'bg-neutral-200' : 'bg-white'"}
                        x-on:mouseenter={"if (new Date().getTime() - lastKeyChangeTime > 500) { selected = #{idx} }"}
                        role="option"
                        tabindex="-1"
                        data-selector-index={idx}
                      >
                        <article class="flex flex-wrap md:flex-nowrap w-full gap-1 justify-leading text-sm max-w-full overflow-hidden">
                          <div
                            class="font-mono font-medium text-neutral-500 pr-2 whitespace-nowrap"
                            data-tooltip={"#{item.media.attr_description} (#{item.media.attr_status})"}
                          >
                            <%= Platform.Material.Media.slug_to_display(item.media) %>/<%= item.scoped_id %>
                          </div>
                          <div class="max-w-full flex-grow-1">
                            <p class="leading-snug font-medium">
                              <%= if Platform.Material.get_media_version_title(item) != nil do %>
                                <%= Platform.Material.get_media_version_title(item)
                                |> Platform.Utils.truncate(100) %>
                              <% else %>
                                Uploaded File
                              <% end %>
                            </p>
                            <%= if Platform.Material.get_media_version_title(item) != item.source_url do %>
                              <p class="text-neutral-500 text-xs">
                                <%= item.source_url |> Platform.Utils.truncate(80) %>
                              </p>
                            <% end %>
                          </div>
                        </article>
                      </li>
                    </.link>
                  <% end %>
                </ul>
              </li>
              <li :if={not Enum.empty?(@results.projects)}>
                <h2 class="text-xs font-medium text-neutral-500">Projects</h2>
                <ul class="-mx-4 mt-2 text-sm text-neutral-700">
                  <%= for {item, idx} <- @results.projects do %>
                    <.link navigate={"/projects/#{item.id}"} class="cursor-pointer">
                      <li
                        id={item.id}
                        class="group flex transition rounded mx-2 ease-in-out duration-100 select-none items-center px-2 py-2"
                        x-bind:class={"#{idx} === (selected % #{@total_results}) ? 'bg-neutral-200' : 'bg-white'"}
                        x-on:mouseenter={"if (new Date().getTime() - lastKeyChangeTime > 500) { selected = #{idx} }"}
                        role="option"
                        tabindex="-1"
                        data-selector-index={idx}
                      >
                        <article class="flex flex-nowrap w-full gap-1 justify-between text-sm items-center max-w-full overflow-hidden">
                          <div class="flex-shrink-0 pr-1 -ml-1">
                            <span style={"color: #{item.color}"}>
                              <svg
                                xmlns="http://www.w3.org/2000/svg"
                                viewBox="0 0 20 20"
                                fill="currentColor"
                                class="w-6 h-6"
                              >
                                <circle cx="10" cy="10" r="5" />
                              </svg>
                            </span>
                          </div>
                          <p class="font-medium flex-grow-1 flex items-center max-w-full gap-2 grow truncate min-w-0">
                            <%= item.name %>
                          </p>
                        </article>
                      </li>
                    </.link>
                  <% end %>
                </ul>
              </li>
              <li :if={not Enum.empty?(@results.updates)}>
                <h2 class="text-xs font-medium text-neutral-500">Updates and Comments</h2>
                <ul class="-mx-4 mt-2 text-sm text-neutral-700">
                  <%= for {item, idx} <- @results.updates do %>
                    <div
                      x-on:click={"window.location = '/incidents/#{item.media.slug}/#update-#{item.id}'"}
                      id={item.id}
                      class="cursor-pointer group flex transition rounded mx-2 ease-in-out duration-100 select-none items-center px-2 pb-2"
                      x-bind:class={"#{idx} === (selected % #{@total_results}) ? 'bg-neutral-200' : 'bg-white'"}
                      x-on:mouseenter={"if (new Date().getTime() - lastKeyChangeTime > 500) { selected = #{idx} }"}
                      role="option"
                      tabindex="-1"
                      data-selector-index={idx}
                    >
                      <div class="pointer-events-none">
                        <.update_entry
                          socket={@socket}
                          can_user_change_visibility={false}
                          profile_ring={false}
                          left_indicator={:small_profile}
                          update={item}
                          current_user={@current_user}
                          show_line={false}
                          show_media={true}
                        />
                      </div>
                    </div>
                  <% end %>
                </ul>
              </li>
            </ul>
            <div :if={not @has_any_results} class="px-6 py-14 text-center text-sm sm:px-14">
              <svg
                class="mx-auto h-6 w-6 text-gray-400"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"
                />
              </svg>
              <p class="mt-4 font-semibold text-gray-900">No results found</p>
              <p class="mt-2 text-gray-500">
                We couldn’t find anything that matches <span class="font-medium"><%= @query %></span>. Please try again.
              </p>
            </div>

            <div class="flex flex-wrap items-center bg-gray-50 px-4 py-2.5 text-xs text-gray-700">
              Search for anything with <kbd class="flex h-5 items-center justify-center rounded border border-gray-300 font-semibold text-gray-700 px-1 mx-1">
                Ctrl K
              </kbd>. Use arrow keys to navigate,
              <kbd class="flex h-5 items-center justify-center rounded border border-gray-300 font-semibold text-gray-700 px-1 mx-1">
                enter
              </kbd>
              to select, and
              <kbd class="flex h-5 items-center justify-center rounded border border-gray-300 font-semibold text-gray-700 px-1 mx-1">
                esc
              </kbd>
              to close.
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
