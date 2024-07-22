defmodule PlatformWeb.SearchLive.SearchComponent do
  @moduledoc """
  This module contains some reasonably complex logic for handling the global search
  component. Pay particular attention to the way that we interact with local state
  using AlpineJS. A lot of the "smooth" interactions are implemented duplicitously:
  For example, we have two different ways for selecting results — one via clicking,
  and the other via keyboard navigation. There is a lot of ad-hoc logic in here to
  get the user interactions "just right".
  """

  use PlatformWeb, :live_component

  alias Platform.GlobalSearch

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)

    {:ok,
     socket
     |> assign_results("")}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign_results(query)}
  end

  defp assign_results(socket, query) do
    results_with_ranks = GlobalSearch.perform_search(query, socket.assigns.current_user)

    results =
      Enum.map(results_with_ranks, fn {k, v} -> {k, Enum.map(v, & &1.item)} end) |> Enum.into(%{})

    # We must assign an ordinal to each result so that we can use it in the
    # template to determine which result is selected. There must be only one instance
    # of each ordinal across all result types.
    result_order =
      Map.keys(results_with_ranks)
      |> Enum.sort_by(
        fn x ->
          {Enum.max(
             Enum.map(results_with_ranks[x], fn %{exact_match: em, cd_rank: rank} ->
               if em do
                 9999
               else
                 rank
               end
             end),
             fn -> -1 end
           ), length(Map.keys(results)) - Enum.find_index(Map.keys(results), &(&1 == x)), x}
        end,
        :desc
      )

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
    |> assign(:result_order, result_order)
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
      x-data="{
        active: false,
        selected: 0,
        selectDebounceStart: 0,
        scrollDebounceStart: 0,
        setSelectedViaHover(val) {
          // We only want to change the selected value if the last key change was
          // more than 500ms ago. This prevents the user's mouse from interfering with
          // the keyboard navigation.
          if (new Date().getTime() - this.selectDebounceStart > 500) {
            this.selected = val
            // We don't want to scroll into view for hover selections
            this.scrollDebounceStart = new Date().getTime()
          }
        },
        isSelected(val, total, idx) {
          return ((val % total) + total) % total === idx
        },
        setActive(val) {
          this.active = val
          this.selectDebounceStart = new Date().getTime()

          if (val) {
            window.stopBodyScroll()
          } else {
            window.resumeBodyScroll()
          }
        },
        openItem(event, link) {
          // If the user is holding down ctrl or meta, open the link in a new tab.
          // If the link is the same as the current page, tell the user they're already on this page.
          if (event.ctrlKey || event.metaKey) {
            window.open(link, '_blank')
          } else if ((window.location.pathname + window.location.hash) === link) {
            this.setActive(false)
          } else {
            window.location = link
          }
        }
      }"
      id="globalsearch"
      class="w-full flex flex-col items-center"
      x-on:keydown.escape.window.prevent="setActive(false)"
      x-on:keydown.ctrl.k.window.prevent="setActive(!active)"
      x-on:keydown.meta.k.window.prevent="setActive(!active)"
      x-effect={"
        if (selected >= #{@total_results}) {
          selected = 0
        } else if (selected < 0) {
          selected = #{@total_results - 1}
        }

        if (active && new Date().getTime() - scrollDebounceStart > 100) {
          $refs.body.querySelectorAll(`[data-selector-index='${selected}']`).forEach(x => x.scrollIntoView())
        }
      "}
    >
      <button type="button" x-on:click="setActive(true)" class="w-full">
        <%= render_slot(@inner_block) %>
      </button>
      <article x-cloak x-ref="body">
        <div
          x-bind:class="active ? 'fixed z-10 w-screen h-screen' : ''"
          role="dialog"
          aria-modal="true"
        >
          <div class="fixed inset-0 bg-neutral-600 bg-opacity-25" x-show="active" x-transition.opacity>
          </div>
          <div
            class="fixed inset-0 z-10 md:ml-14 w-screen overflow-y-auto p-4 sm:p-6 md:p-20"
            x-transition
            x-show="active"
          >
            <div
              class="mx-auto max-w-xl lg:max-w-2xl transform divide-y divide-gray-100 overflow-hidden rounded-xl bg-white shadow-2xl ring-1 ring-black ring-opacity-5"
              x-on:click.outside="setActive(false)"
              data-blocks-body-scroll="true"
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
                <form
                  phx-change="search"
                  phx-submit="search"
                  phx-target={@myself}
                  phx-update="ignore"
                  id="globalsearch-form"
                >
                  <input
                    type="text"
                    phx-debounce="200"
                    class="h-12 w-full border-0 bg-transparent pl-11 pr-4 text-gray-900 placeholder:text-gray-400 focus:ring-0 sm:text-sm"
                    placeholder="Search..."
                    role="combobox"
                    aria-expanded="false"
                    aria-controls="options"
                    name="query"
                    x-ref="input"
                    id="globalsearch-input"
                    tabindex="0"
                    value={@query}
                    x-effect="
                      if (active && !document.activeElement.isSameNode($refs.input)) {
                        // We need to wait for the input to be visible before we can focus it.
                        setTimeout(() => { $refs.input.focus(); $refs.input.select() }, 10)
                      }
                    "
                  />
                </form>
              </div>
              <ul
                :if={@has_any_results}
                class="max-h-[70vh] scroll-smooth transform-gpu scroll-py-10 scroll-pb-2 space-y-4 overflow-y-auto p-4 pb-2"
                id="options"
                role="listbox"
              >
                <%= for result_type <- @result_order do %>
                  <%= case result_type do %>
                    <% :users -> %>
                      <li :if={not Enum.empty?(@results.users)}>
                        <h2 class="text-xs font-medium text-neutral-500">Users</h2>
                        <ul class="-mx-4 mt-2 text-sm text-neutral-700">
                          <%= for {user, idx} <- @results.users do %>
                            <.link
                              navigate={"/profile/#{user.username}"}
                              class="cursor-pointer"
                              id={"result-#{idx}-#{user.id}"}
                            >
                              <li
                                id={user.id}
                                class="group flex transition rounded mx-2 ease-in-out duration-100 select-none items-center px-2 py-2"
                                x-bind:class={"isSelected(selected, #{@total_results}, #{idx}) ? 'bg-neutral-200' : 'bg-white'"}
                                x-on:mouseenter={"setSelectedViaHover(#{idx})"}
                                role="option"
                                tabindex="-1"
                                data-selector-index={idx}
                              >
                                <img
                                  src={Platform.Accounts.get_profile_photo_path(user)}
                                  alt=""
                                  class="h-6 w-6 flex-none rounded-full"
                                />
                                <span class="ml-3 flex-auto truncate font-medium">
                                  <%= user.username %>
                                </span>
                              </li>
                            </.link>
                          <% end %>
                        </ul>
                      </li>
                    <% :media -> %>
                      <li :if={not Enum.empty?(@results.media)}>
                        <h2 class="text-xs font-medium text-neutral-500">Incidents</h2>
                        <ul class="-mx-4 mt-2 text-sm text-neutral-700">
                          <%= for {item, idx} <- @results.media do %>
                            <.link
                              navigate={"/incidents/#{item.slug}"}
                              class="cursor-pointer"
                              id={"result-#{idx}-#{item.id}"}
                            >
                              <li
                                id={item.id}
                                class="group flex transition rounded mx-2 ease-in-out duration-100 items-center px-2 py-2"
                                x-bind:class={"isSelected(selected, #{@total_results}, #{idx}) ? 'bg-neutral-200' : 'bg-white'"}
                                x-on:mouseenter={"setSelectedViaHover(#{idx})"}
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
                    <% :media_versions -> %>
                      <li :if={not Enum.empty?(@results.media_versions)}>
                        <h2 class="text-xs font-medium text-neutral-500">Source Material</h2>
                        <ul class="-mx-4 mt-2 text-sm text-neutral-700">
                          <%= for {item, idx} <- @results.media_versions do %>
                            <.link
                              navigate={"/incidents/#{item.media.slug}/detail/#{item.id}"}
                              class="cursor-pointer"
                              id={"result-#{idx}-#{item.id}"}
                            >
                              <li
                                id={item.id}
                                class="group flex transition rounded mx-2 ease-in-out duration-100 select-none items-center px-2 py-2"
                                x-bind:class={"isSelected(selected, #{@total_results}, #{idx}) ? 'bg-neutral-200' : 'bg-white'"}
                                x-on:mouseenter={"setSelectedViaHover(#{idx})"}
                                role="option"
                                tabindex="-1"
                                data-selector-index={idx}
                              >
                                <article class="flex flex-wrap md:flex-nowrap w-full gap-1 justify-leading text-sm max-w-full overflow-hidden">
                                  <div
                                    class="font-mono font-medium text-neutral-500 pr-2 whitespace-nowrap"
                                    data-tooltip={"#{item.media.attr_description} (#{item.media.attr_status})"}
                                  >
                                    <%= item.id %> <%= if not Enum.empty?(item.media),
                                      do:
                                        "( " ++
                                          Enum.join(
                                            item.media
                                            |> Enum.map(&Platform.Material.slug_to_display(&1)),
                                            ", "
                                          ) ++ ")" %>
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
                    <% :projects -> %>
                      <li :if={not Enum.empty?(@results.projects)}>
                        <h2 class="text-xs font-medium text-neutral-500">Projects</h2>
                        <ul class="-mx-4 mt-2 text-sm text-neutral-700">
                          <%= for {item, idx} <- @results.projects do %>
                            <.link
                              navigate={"/projects/#{item.id}"}
                              class="cursor-pointer"
                              id={"result-#{idx}-#{item.id}"}
                            >
                              <li
                                id={item.id}
                                class="group flex transition rounded mx-2 ease-in-out duration-100 select-none items-center px-2 py-2"
                                x-bind:class={"isSelected(selected, #{@total_results}, #{idx}) ? 'bg-neutral-200' : 'bg-white'"}
                                x-on:mouseenter={"setSelectedViaHover(#{idx})"}
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
                                  <p
                                    :if={not item.active}
                                    class="text-sm text-yellow-600 flex gap-1 items-center"
                                  >
                                    <Heroicons.archive_box mini class="h-4 w-4 opacity-50" /> Archived
                                  </p>
                                </article>
                              </li>
                            </.link>
                          <% end %>
                        </ul>
                      </li>
                    <% :updates -> %>
                      <li :if={not Enum.empty?(@results.updates)}>
                        <h2 class="text-xs font-medium text-neutral-500">Updates</h2>
                        <ul class="-mx-4 mt-2 text-sm text-neutral-700">
                          <%= for {item, idx} <- @results.updates do %>
                            <div
                              x-on:click={"openItem($event, '/incidents/#{item.media.slug}/#update-#{item.id}')"}
                              id={"result-#{idx}-#{item.id}"}
                              class="cursor-pointer group transition rounded mx-2 ease-in-out duration-100 select-none px-2 pb-2"
                              x-bind:class={"isSelected(selected, #{@total_results}, #{idx}) ? 'bg-neutral-200' : 'bg-white'"}
                              x-on:mouseenter={"setSelectedViaHover(#{idx})"}
                              role="option"
                              tabindex="-1"
                              data-selector-index={idx}
                            >
                              <div class="pointer-events-none w-full">
                                <.update_entry
                                  profile_ring={false}
                                  left_indicator={:small_profile}
                                  update={item}
                                  current_user={@current_user}
                                  show_line={false}
                                  show_media={true}
                                  id_prefix="search"
                                />
                              </div>
                            </div>
                          <% end %>
                        </ul>
                      </li>
                  <% end %>
                <% end %>
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
        <template x-if="active">
          <span
            x-on:keydown.down.window.prevent="selected = selected + 1; selectDebounceStart = new Date().getTime();"
            x-on:keydown.up.window.prevent="selected = selected - 1; selectDebounceStart = new Date().getTime();"
            x-on:keydown.enter.window.prevent="$refs.body.querySelectorAll(`[data-selector-index='${selected}']`).forEach(x => x.click()); setActive(false)"
          >
          </span>
        </template>
      </article>
    </div>
    """
  end
end
