defmodule PlatformWeb.MediaLive.SearchForm do
  use PlatformWeb, :live_component
  require PlatformWeb.Components
  alias Platform.Material.Attribute
  alias Platform.Material
  alias Platform.Utils
  alias Platform.Projects.ProjectAttribute

  def mount(socket) do
    {:ok,
     socket
     |> assign_new(:select_state, fn -> "norm" end)
     |> assign_new(:cur_select, fn -> "" end)
     |> assign_new(:exclude, fn -> [] end)}
  end

  def update(%{changeset: c} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, Map.put(c, :action, :validate))
     |> preprocess_attrs(assigns)}
  end

  defp preprocess_attrs(socket, %{changeset: c} = assigns) do
    default_attrs =
      ["status", "geolocation", "date", "tags", "sensitive"]
      |> Enum.map(fn x ->
        at =
          Attribute.get_attribute(x,
            projects:
              if(x == "tags",
                do: Platform.Projects.list_projects_for_user(assigns.current_user),
                else: []
              )
          )

        %{
          id: "#{x}_filter",
          attr: at,
          label: at.label
        }
      end)

    available_attrs =
      default_attrs
      |> Enum.concat(
        if assigns.active_project,
          do:
            assigns.active_project.attributes
            |> Enum.map(
              &%{
                id: "#{&1.id}_filter",
                attr: ProjectAttribute.to_attribute(&1),
                label: &1.name
              }
            ),
          else: []
      )

    initial_toggle =
      Enum.reduce(
        available_attrs,
        %{},
        fn atr, acc ->
          Map.put(acc, atr.id, is_active?(c, atr.attr))
        end
      )

    socket
    |> assign(:available_attrs, available_attrs)
    |> assign_new(:toggle_state, fn -> initial_toggle end)
  end

  def handle_event("select_state_filt", _par, socket) do
    {:noreply, assign(socket, :select_state, "select_filt")}
  end

  def handle_event("select_state_norm", %{"active" => active, "attr" => attr_id}, socket) do
    socket = socket |> assign(:select_state, "norm") |> assign(:cur_select, "")

    if not active do
      {:noreply,
       socket |> assign(:toggle_state, Map.put(socket.assigns.toggle_state, attr_id, false))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cur_select", %{"select" => select}, socket) do
    {:noreply, assign(socket, :cur_select, select)}
  end

  def handle_event("toggle", %{"attr" => attr_id}, socket) do
    {:noreply,
     assign(
       socket,
       :toggle_state,
       Map.put(
         socket.assigns.toggle_state,
         attr_id,
         not Map.get(socket.assigns.toggle_state, attr_id, false)
       )
     )}
  end

  def handle_event(event, _par, socket) do
    {:noreply, socket}
  end

  defp relevant_ids(attr_obj, attr_id) do
    case attr_obj.type do
      x when x == :multi_select or x == :select ->
        [attr_id]

      :location ->
        [attr_id, "#{attr_id}_radius"]

      :date ->
        ["#{attr_id}_min", "#{attr_id}_max"]

      :text ->
        ["#{attr_id}_matchtype", attr_id]

      _ ->
        []
    end
  end

  defp cs_remove_attr(cs, attr_obj, attr_id) do
    rel = relevant_ids(attr_obj, attr_id)
    Enum.reduce(rel, cs, fn id, acc -> Map.put(acc, id, nil) end)
  end

  defp attr_filter(assigns) do
    assigns =
      assigns
      |> assign(
        :default_open,
        if(is_nil(assigns[:default_open]), do: false, else: assigns.default_open)
      )

    ~H"""
    <article
      class="relative text-left overflow-visible"
      x-data={"{open: #{@default_open}}"}
      x-on:mousedown.outside="open = false"
      id={@id}
    >
      <div class={if @default_open, do: "hidden", else: ""}>
        <div class="flex h-8 border shadow-sm rounded-lg justify-center items-center overflow-hidden">
          <button
            type="button"
            class={"transition-all flex-auto h-full flex justify-center items-center px-2 gap-x-1 text-sm " <> if @is_active
            do "text-white bg-urge-500 border-urge-500"
            else "text-gray-900 bg-white"
          end}
            aria-haspopup="true"
            x-on:click="open = !open"
          >
            <.filter_icon type={@attr.type} />
            <%= @attr.label %>
          </button>
          <button
            type="button"
            class={"transition flex-none flex items-center justify-center text-gray-500w-5 h-full my-auto px-0.5 " <> if @is_active
            do "bg-urge-500 hover:bg-urge-600 text-neutral-200"
            else "bg-transparent hover:bg-neutral-100 text-neutral-500"
          end}
            phx-click={
              JS.push("toggle", value: %{"attr" => @_attr.id}, target: @myself)
              |> JS.push("save",
                value: %{
                  "search" =>
                    @changeset.changes
                    |> cs_remove_attr(@attr, @attr_id)
                }
              )
              |> JS.dispatch("atlos:updating", to: "body")
            }
          >
            <Heroicons.x_mark mini class="h-5 w-5" />
          </button>
        </div>
      </div>
      <div
        class="absolute right-0 z-[10000] overflow-visible mt-2 w-96 origin-top-right rounded-lg bg-white shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none"
        role="menu"
        x-transition
        aria-orientation="vertical"
        tabindex="-1"
        x-show="open"
        x-cloak
      >
        <div class="p-2" role="none">
          <p class="text-xs font-medium uppercase tracking-wide text-gray-500 mb-1">
            Filter <%= @attr.label %>
          </p>
          <div>
            <%= case @attr.type do %>
              <% x when x == :multi_select or x == :select -> %>
                <div phx-update="ignore" id={"attr_select_#{@attr.name}_#{@id}"} class="phx-form">
                  <%= multiple_select(
                    @form,
                    "#{@attr_id}",
                    Attribute.options(@attr) ++ if(not @attr.required, do: ["[Unset]"], else: []),
                    selected: @form.source.changes["#{@attr_id}"] || [],
                    id: "attr_select_#{@attr.name}_input_#{@id}",
                    data_descriptions:
                      Jason.encode!(
                        (@attr.option_descriptions || %{})
                        |> Map.put("[Unset]", "No #{String.downcase(@attr.label)} set")
                      )
                  ) %>
                </div>
              <% :location -> %>
                <div>
                  <div class="flex flex-col gap-2 items-center ts-ignore">
                    <%= text_input(
                      @form,
                      :attr_geolocation,
                      class: "input-base grow",
                      placeholder: "Latitude, Longitude",
                      "phx-debounce": "500",
                      id: "#{@id}_search-form-#{@attr_id}"
                    ) %>
                    <span class="text-gray-600 text-sm">within</span>
                    <%= select(
                      @form,
                      :attr_geolocation_radius,
                      [
                        {"1 km", 1},
                        {"5 km", 5},
                        {"10 km", 10},
                        {"25 km", 25},
                        {"50 km", 50},
                        {"100 km", 100},
                        {"250 km", 250},
                        {"500 km", 500},
                        {"1000 km", 1000}
                      ],
                      default: 10,
                      class: "input-base shrink",
                      id: "#{@id}_search-form-#{@attr_id}_radius"
                    ) %>
                  </div>
                  <p class="support text-gray-600 my-1">
                    Input the location in the format: <code>latitude, longitude</code>
                  </p>
                  <p class="support text-critical-600">
                    <%= error_tag(@form, :attr_geolocation) %>
                  </p>
                </div>
              <% :date -> %>
                <div>
                  <div class="flex gap-2 items-center">
                    <%= date_input(
                      @form,
                      :attr_date_min,
                      id: "#{@id}_search-form-date-min",
                      class: "input-base inline-flex items-center",
                      phx_debounce: 2000
                    ) %>
                    <span class="text-sm text-gray-600">until</span>
                    <%= date_input(
                      @form,
                      :attr_date_max,
                      id: "#{@id}_search-form-date-max",
                      class: "input-base inline-flex items-center",
                      phx_debounce: 2000
                    ) %>
                  </div>
                  <p class="support text-gray-600 mt-1">
                    For an open ended range, leave the field blank.
                  </p>
                </div>
              <% :text -> %>
                <div class="ts-ignore">
                  <%= select(
                    @form,
                    "#{@attr_id}-matchtype",
                    [Contains: :contains, Equals: :equals, "Does not Contain": :excludes],
                    class: "block input-base grow",
                    id: "#{@id}_search-form-#{@attr_id}_matchtype"
                  ) %>
                  <%= text_input(
                    @form,
                    "#{@attr_id}",
                    class: "input-base grow mt-2",
                    "phx-debounce": "500",
                    id: "#{@id}_search-form-#{@attr_id}"
                  ) %>
                </div>
              <% _ -> %>
                TODO
            <% end %>
          </div>
        </div>
      </div>
    </article>
    """
  end

  defp get_change(cs, attr) do
    Map.get(cs.changes, attr, nil)
  end

  defp get_change(cs, attr, default) do
    Map.get(cs.changes, attr, default)
  end

  defp is_active?(cs, attr) do
    get_change(cs, attr.schema_field) != nil or
      (attr.type == :date and
         (get_change(cs, :attr_date_min) != nil or
            get_change(cs, :attr_date_max) != nil)) or
      get_change(
        cs,
        Material.MediaSearch.get_attrid(attr)
      ) != nil
  end

  def render(%{changeset: c, query_params: _, socket: _, display: _} = assigns) do
    ~H"""
    <div
      x-data="{
        open: window.innerWidth >= 768,
        contains(source, query){
          return source.toLowerCase().includes(query.toLowerCase());
        }
      }"
      id={"search-form-component-#{get_change(@changeset, :display) |> to_string()}"}
    >
      <button
        x-on:click="open = !open"
        class="mx-auto md:hidden bg-white hover:shadow-lg hover:bg-neutral-100 focus:ring-urge-400 transition-all rounded-full gap-1 px-3 py-2 text-sm flex items-center shadow text-neutral-700 justify-around mb-4"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="currentColor"
          class="w-5 h-5 text-neutral-500"
        >
          <path
            fill-rule="evenodd"
            d="M11.078 2.25c-.917 0-1.699.663-1.85 1.567L9.05 4.889c-.02.12-.115.26-.297.348a7.493 7.493 0 00-.986.57c-.166.115-.334.126-.45.083L6.3 5.508a1.875 1.875 0 00-2.282.819l-.922 1.597a1.875 1.875 0 00.432 2.385l.84.692c.095.078.17.229.154.43a7.598 7.598 0 000 1.139c.015.2-.059.352-.153.43l-.841.692a1.875 1.875 0 00-.432 2.385l.922 1.597a1.875 1.875 0 002.282.818l1.019-.382c.115-.043.283-.031.45.082.312.214.641.405.985.57.182.088.277.228.297.35l.178 1.071c.151.904.933 1.567 1.85 1.567h1.844c.916 0 1.699-.663 1.85-1.567l.178-1.072c.02-.12.114-.26.297-.349.344-.165.673-.356.985-.57.167-.114.335-.125.45-.082l1.02.382a1.875 1.875 0 002.28-.819l.923-1.597a1.875 1.875 0 00-.432-2.385l-.84-.692c-.095-.078-.17-.229-.154-.43a7.614 7.614 0 000-1.139c-.016-.2.059-.352.153-.43l.84-.692c.708-.582.891-1.59.433-2.385l-.922-1.597a1.875 1.875 0 00-2.282-.818l-1.02.382c-.114.043-.282.031-.449-.083a7.49 7.49 0 00-.985-.57c-.183-.087-.277-.227-.297-.348l-.179-1.072a1.875 1.875 0 00-1.85-1.567h-1.843zM12 15.75a3.75 3.75 0 100-7.5 3.75 3.75 0 000 7.5z"
            clip-rule="evenodd"
          />
        </svg>
        View Options
      </button>
      <div x-show="open" x-transition x-ref="form">
        <.form
          :let={f}
          as={:search}
          for={@changeset}
          id="search-form"
          phx-change={JS.push("validate") |> JS.dispatch("atlos:updating", to: "body")}
          phx-submit={JS.push("save") |> JS.dispatch("atlos:updating", to: "body")}
          data-no-warn="true"
          class="w-full"
        >
          <section class="flex flex-col items-start w-full max-w-7xl mx-auto flex-wrap md:flex-nowrap gap-2 items-center">
            <div class="flex w-full divide-y md:divide-y-0 flex-col flex-grow md:flex-row rounded-lg bg-white shadow-sm border">
              <%= if not Enum.member?(@exclude, :display) do %>
                <div class="flex px-2 py-1 pd:my-0 md:border-r">
                  <nav class="flex items-center gap-px" aria-label="Tabs">
                    <%= label do %>
                      <div
                        data-tooltip="Map view"
                        class={"cursor-pointer transition-all px-2 py-[0.38rem] font-medium text-sm rounded-md " <> (if @display == "map", do: "bg-neutral-200 text-neutral-700", else: "text-neutral-700 hover:bg-neutral-100")}
                      >
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke-width="1.5"
                          stroke="currentColor"
                          class="w-6 h-6"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M9 6.75V15m6-6v8.25m.503 3.498l4.875-2.437c.381-.19.622-.58.622-1.006V4.82c0-.836-.88-1.38-1.628-1.006l-3.869 1.934c-.317.159-.69.159-1.006 0L9.503 3.252a1.125 1.125 0 00-1.006 0L3.622 5.689C3.24 5.88 3 6.27 3 6.695V19.18c0 .836.88 1.38 1.628 1.006l3.869-1.934c.317-.159.69-.159 1.006 0l4.994 2.497c.317.158.69.158 1.006 0z"
                          />
                        </svg>
                      </div>
                      <%= radio_button(f, :display, "map",
                        class: "fixed opacity-0 pointer-events-none",
                        "x-on:change": "window.triggerSubmitEvent($event.target)"
                      ) %>
                    <% end %>

                    <%= label do %>
                      <div
                        data-tooltip="Card view"
                        class={"cursor-pointer transition-all px-2 py-[0.38rem] font-medium text-sm rounded-md " <> (if @display == "cards", do: "bg-neutral-200 text-neutral-700", else: "text-neutral-700 hover:bg-neutral-100")}
                      >
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke-width="1.5"
                          stroke="currentColor"
                          class="w-6 h-6"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"
                          />
                        </svg>
                      </div>
                      <%= radio_button(f, :display, "cards",
                        id: "search-form-cards-button",
                        class: "fixed opacity-0 pointer-events-none",
                        "x-on:change": "window.triggerSubmitEvent($event.target)"
                      ) %>
                    <% end %>

                    <%= label do %>
                      <div
                        data-tooltip="Table view"
                        class={"cursor-pointer transition-all px-2 py-[0.38rem] font-medium text-sm rounded-md " <> (if @display == "table", do: "bg-neutral-200 text-neutral-700", else: "text-neutral-700 hover:bg-neutral-100")}
                      >
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke-width="1.5"
                          stroke="currentColor"
                          class="w-6 h-6"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M8.25 6.75h12M8.25 12h12m-12 5.25h12M3.75 6.75h.007v.008H3.75V6.75zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zM3.75 12h.007v.008H3.75V12zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm-.375 5.25h.007v.008H3.75v-.008zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
                          />
                        </svg>
                      </div>
                      <%= radio_button(f, :display, "table",
                        class: "fixed opacity-0 pointer-events-none",
                        "x-on:change": "window.triggerSubmitEvent($event.target)"
                      ) %>
                    <% end %>
                  </nav>
                </div>
              <% end %>
              <div class={if Enum.member?(@exclude, :project), do: "hidden", else: ""}>
                <div class="ts-ignore pl-3 py-2 group md:border-r min-w-[8rem]">
                  <%= label(f, :project_id, "Project",
                    class: "block text-xs font-medium text-gray-900 group-focus-within:text-urge-600"
                  ) %>
                  <%= select(
                    f,
                    :project_id,
                    [{"All", nil}] ++
                      (Platform.Projects.list_projects_for_user(@current_user)
                       |> Enum.map(fn p -> {p.code <> ": " <> p.name, p.id} end)
                       |> Enum.map(fn {name, id} -> {Utils.truncate(name, 20), id} end)),
                    id:
                      "search-form-project-select-#{get_change(f.source, :project_id)}",
                    class:
                      "block bg-transparent w-full border-0 py-0 pl-0 pr-7 text-gray-900 placeholder-gray-500 focus:ring-0 sm:text-sm"
                  ) %>
                </div>
                <%= error_tag(f, :project_id) %>
              </div>
              <div class={"flex-grow " <> (if Enum.member?(@exclude, :query), do: "hidden", else: "")}>
                <div class="px-3 h-full group flex flex-col md:flex-row py-2 items-center">
                  <%= label(f, :query, "Search",
                    class:
                      "block w-full md:hidden text-xs font-medium text-gray-900 group-focus-within:text-urge-600"
                  ) %>
                  <%= text_input(f, :query,
                    placeholder: "Filter incidents...",
                    phx_debounce: "1000",
                    id: "search-form-query-input",
                    "x-on:keydown.enter": "window.triggerSubmitEvent($event.target)",
                    class:
                      "block w-full border-0 p-0 bg-transparent text-gray-900 placeholder-gray-500 focus:ring-0 sm:text-sm"
                  ) %>
                </div>
                <%= error_tag(f, :query) %>
              </div>
              <div class={if Enum.member?(@exclude, :sort), do: "hidden", else: ""}>
                <div class="ts-ignore pl-3 py-2 group border-x">
                  <%= label(f, :sort, "Sort",
                    class: "block text-xs font-medium text-gray-900 group-focus-within:text-urge-600"
                  ) %>
                  <%= select(
                    f,
                    :sort,
                    [
                      "Newest Added": :uploaded_desc,
                      "Oldest Added": :uploaded_asc,
                      "Recently Modified": :modified_desc,
                      "Least Recently Modified": :modified_asc,
                      "Description (A-Z)": :description_asc,
                      "Description (Z-A)": :description_desc
                    ],
                    class:
                      "block bg-transparent w-full border-0 py-0 pl-0 pr-7 text-gray-900 placeholder-gray-500 focus:ring-0 sm:text-sm"
                  ) %>
                </div>
                <%= error_tag(f, :sort) %>
              </div>
              <div
                class={"flex place-self-center w-full md:w-auto h-full pr-2 pl-1 text-sm md:py-[14px] py-4 pl-2 " <>
                  (if Enum.member?(@exclude, :more_options), do: "hidden", else: "")}
                x-data="{
                  open: false
                }"
              >
                <div class="text-left z-10">
                  <div class="h-full flex gap-1">
                    <%= button type: "button", to: Routes.export_path(@socket, :create_csv_export, @query_params),
                      class: "rounded-full flex items-center align-center text-gray-600 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-100 focus:ring-urge-500",
                      role: "menuitem",
                      method: :post,
                      "x-cloak": true,
                      data_tooltip: "Export Incidents"
                    do %>
                      <Heroicons.arrow_down_tray mini class="h-5 w-5" />
                      <span class="sr-only">Export Incidents</span>
                    <% end %>
                    <.link
                      navigate={"/incidents?display=#{get_change(f.source, :display, "cards")}"}
                      class="rounded-full flex items-center align-center text-gray-600 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-100 focus:ring-urge-500"
                      role="menuitem"
                      data-tooltip="Reset Filters"
                    >
                      <Heroicons.x_mark mini class="h-6 w-6" />
                      <span class="sr-only">Reset Filters</span>
                    </.link>
                  </div>
                </div>
              </div>
            </div>
            <div class={"flex bg-white border rounded sm:border-none sm:rounded-none sm:bg-transparent p-4 sm:p-0 justify-between gap-4 items-center w-full flex-col-reverse sm:flex-row " <> if Enum.member?(@exclude, :pagination) and Enum.member?(@exclude, :filters), do: "hidden", else: ""}>
              <div class={if Enum.member?(@exclude, :pagination), do: "hidden", else: ""}>
                <%= if assigns[:pagination] do %>
                  <%= render_slot(@pagination) %>
                <% end %>
              </div>
              <div class={if Enum.member?(@exclude, :filters), do: "hidden", else: ""}>
                <div class="relative flex flex-wrap items-center h-full gap-2">
                  <br />
                  <%= for attr <- @available_attrs do %>
                    <%= if (@toggle_state[attr.id] || 'false') == true && !(@cur_select == attr.id && @select_state == "select_filt") do %>
                      <div
                        x-transition
                        x-show={"#{@toggle_state[attr.id] || 'false'}===true && !('#{@cur_select}'===\"#{attr.id}\" && '#{@select_state}'==='select_filt')"}
                      >
                        <.attr_filter
                          id={attr.id}
                          type={:bar}
                          attr_id={Material.MediaSearch.get_attrid(attr.attr)}
                          form={f}
                          is_active={is_active?(@changeset, attr.attr)}
                          attr={attr.attr}
                          _attr={attr}
                          myself={@myself}
                          changeset={@changeset}
                        />
                      </div>
                    <% end %>
                  <% end %>
                  <article
                    x-data="{
                    init() {
                      Alpine.store('dropdown', { sel: 0 });
                      this.updateLen();

                    },
                    open: false,
                    updateLen() {
                      $store.dropdown.len = this.getbtns().length;
                    },
                    getbtns() {
                      return document.querySelectorAll('#attr-list > .filter-btn:not([style*=\'display: none\'])');
                    },
                    findId(id) {
                      let attrList = this.getbtns();
                      for (var i = 0; i < attrList.length; i++) {
                        if (attrList[i].id == id) {
                          return i;
                        }
                      }
                      return -1;
                    },
                    setSelectedViaHover(id) {
                      console.log('A', id);
                      $store.dropdown.sel=this.findId(id)
                      console.log('C', $store.dropdown.sel);
                    },
                    clickSelected() {
                      let attrList = this.getbtns();
                      attrList[$store.dropdown.sel].click();
                    },
                  }"
                    x-init="init()"
                    x-effect="
                    let aq = $store.atquery;
                    let sl = $store.dropdown.sel;
                    setTimeout(() => {
                      let len = getbtns().length;
                      if($store.dropdown.sel >= len){
                        $store.dropdown.sel = 0;
                      } else if ($store.dropdown.sel < 0){
                        $store.dropdown.sel = len - 1;
                      }
                    }, 5);
                  "
                    x-on:click.away="open = false"
                  >
                    <template x-if="open">
                      <span
                        x-on:keydown.down.window.prevent="$store.dropdown.sel += 1; console.log('down', $store.dropdown.sel)"
                        x-on:keydown.up.window.prevent="$store.dropdown.sel -= 1; console.log('up', $store.dropdown.sel)"
                        x-on:keydown.enter.window.prevent="clickSelected()"
                        x-on:keydown.esc.window.prevent="open=false"
                      >
                      </span>
                    </template>
                    <div>
                      <button
                        type="button"
                        class="transition-all border shadow-sm rounded-lg h-8 text-sm text-gray-900 bg-white py-1 px-2"
                        x-on:click="open=!open"
                      >
                        <Heroicons.funnel
                          solid
                          class="h-5 w-5 py-px -mt-0.5 inline-block text-gray-600"
                        /> Filter
                      </button>
                    </div>
                    <div
                      x-show={"open && '#{@select_state}'==='norm'"}
                      x-init="Alpine.store('atquery', '')"
                      x-transition
                      x-cloak
                      role="menu"
                      class="transition-all absolute left z-[10000] overflow-visible mt-2 w-44 origin-top-right rounded-lg bg-white shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none p-1"
                    >
                      <input
                        type="text"
                        x-model="$store.atquery"
                        x-ref="fsearch"
                        x-effect="if(open){setTimeout(() => { $refs.fsearch.focus(); $refs.fsearch.select() }, 10)}"
                        phx-target={@myself}
                        phx-change="ignore"
                        id="attrqueryinput"
                        class="h-7 border-none w-full outline-none text-gray-900 placeholder-gray-500 focus:ring-0 sm:text-sm"
                        placeholder="Filter..."
                      />
                      <hr class="my-1 -mx-1" />
                      <div id="attr-list">
                        <%= for attr <- @available_attrs do %>
                          <%= if (@toggle_state[attr.id] || false) == false do %>
                            <button
                              value={attr.id}
                              id={attr.id<>"_drop_button"}
                              x-show={"contains('#{attr.label}', $store.atquery)"}
                              phx-click={
                                JS.push("select_state_filt", target: @myself)
                                |> JS.push("cur_select", value: %{select: attr.id}, target: @myself)
                                |> JS.push("toggle", value: %{attr: attr.id}, target: @myself)
                              }
                              phx-target={@myself}
                              class="w-full text-left rounded transition text-sm text-gray-900 py-1 px-2 flex filter-btn"
                              x-on:mouseenter={"
                              setSelectedViaHover('#{attr.id}_drop_button')
                              curi = findId('#{attr.id}_drop_button');
                              "
                            }
                              x-data="{curi:-1}"
                              x-effect={"
                            let aq = $store.atquery;
                            let sl = $store.dropdown.sel;
                            setTimeout(() => {
                              curi = findId('#{attr.id}_drop_button');
                              console.log('#{attr.id} curi', curi);
                            }, 5)
                            "}
                              x-bind:class="let _ = open; return $store.dropdown.sel == curi ? 'bg-neutral-200' : 'bg-white'"
                            >
                              <.filter_icon type={attr.attr.type} />
                              <span class="ml-2">
                                <%= attr.label %>
                              </span>
                            </button>
                          <% end %>
                        <% end %>
                        <span
                          class="text-sm ml-1 leading-normal text-neutral-500"
                          x-data="{show:false}"
                          x-show="show"
                          x-effect="let aq = $store.atquery;
                            let sl = $store.dropdown.sel;
                            setTimeout(() => {
                              let lst = getbtns();
                              show = lst.length == 0;
                            }, 10)"
                        >
                          No filters found
                        </span>
                        <%= if !@active_project do %>
                          <div
                            data-tooltip="Select a specific project <br/> for more filtering options"
                            data-tooltip-placement="left"
                          >
                            <Heroicons.ellipsis_horizontal class="h-5 w-5 ml-2 py-px inline-block text-neutral-500" />
                            <span class="text-sm ml-1 leading-normal text-neutral-500">
                              More Options
                            </span>
                          </div>
                        <% end %>
                      </div>
                    </div>
                    <%= for attr <- @available_attrs do %>
                      <template x-if={"#{@toggle_state[attr.id] || 'false'}===true && '#{@cur_select}'===\"#{attr.id}\" && '#{@select_state}'==='select_filt'"}>
                        <div
                          x-transition
                          phx-click-away={
                            JS.push("select_state_norm",
                              value: %{active: is_active?(@changeset, attr.attr), attr: attr.id}
                            )
                          }
                          phx-target={@myself}
                        >
                          <.attr_filter
                            id={attr.id<>"_dropdown"}
                            type={:dropdown}
                            attr_id={Material.MediaSearch.get_attrid(attr.attr)}
                            form={f}
                            attr={attr.attr}
                            _attr={attr}
                            changeset={@changeset}
                            is_active={is_active?(@changeset, attr.attr)}
                            myself={@myself}
                            default_open={true}
                          />
                        </div>
                      </template>
                    <% end %>
                  </article>
                  <div
                    class="relative text-left overflow-visible"
                    data-tooltip="Filter to my assignments"
                  >
                    <%= label f, :only_assigned_id, class: "transition-all cursor-pointer flex h-8 border shadow-sm rounded-lg py-1 px-2 w-full justify-center items-center gap-x-1 text-sm text-gray-900 " <> (if get_change(@changeset, :only_assigned_id) == @current_user.id do
                      "text-white bg-urge-500 border-urge-500"
                    else
                      "bg-white text-neutral-600"
                    end) do %>
                      <Heroicons.bookmark solid class="h-5 w-5 py-px" />
                      <%= checkbox(f, :only_assigned_id,
                        class: "hidden",
                        checked_value: @current_user.id
                      ) %>
                    <% end %>
                  </div>
                  <div
                    class="relative text-left overflow-visible"
                    data-tooltip="Filter to my subscriptions"
                  >
                    <%= label f, :only_subscribed_id, class: "transition-all cursor-pointer flex h-8 border shadow-sm rounded-lg py-1 px-2 w-full justify-center items-center gap-x-1 text-sm text-gray-900 " <> (if get_change(@changeset, :only_subscribed_id) == @current_user.id do
                      "text-white bg-urge-500 border-urge-500"
                    else
                      "bg-white text-neutral-600"
                    end) do %>
                      <Heroicons.eye solid class="h-5 w-5 py-px" />
                      <%= checkbox(f, :only_subscribed_id,
                        class: "hidden",
                        checked_value: @current_user.id
                      ) %>
                    <% end %>
                  </div>
                  <div
                    class="relative text-left overflow-visible"
                    data-tooltip="Filter to unread notifications"
                  >
                    <%= label f, :only_has_unread_notifications, class: "transition-all cursor-pointer flex h-8 border shadow-sm rounded-lg py-1 px-2 w-full justify-center items-center gap-x-1 text-sm text-gray-900 " <> (if get_change(@changeset, :only_has_unread_notifications) do
                      "text-white bg-urge-500 border-urge-500"
                    else
                      "bg-white text-neutral-600"
                    end) do %>
                      <Heroicons.bell_alert solid class="h-5 w-5 py-px" />
                      <%= checkbox(f, :only_has_unread_notifications, class: "hidden") %>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          </section>
        </.form>
      </div>
    </div>
    """
  end
end
