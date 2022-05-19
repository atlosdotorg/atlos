defmodule PlatformWeb.Components do
  use Phoenix.Component
  use Phoenix.HTML

  alias Phoenix.LiveView.JS

  alias Platform.Accounts
  alias Platform.Material.Attribute
  alias Platform.Material.Media
  alias Platform.Material
  alias Platform.Utils

  def navlink(%{request_path: path, to: to} = assigns) do
    classes =
      if String.starts_with?(path, to) and !String.equivalent?(path, "/") do
        "bg-neutral-800 text-white group w-full p-3 rounded-md flex flex-col items-center text-xs font-medium"
      else
        "text-neutral-100 hover:bg-neutral-800 hover:text-white group w-full p-3 rounded-md flex flex-col items-center text-xs font-medium"
      end

    ~H"""
    <%= link to: @to, class: classes do %>
      <%= render_slot(@inner_block) %>
      <span class="mt-2"><%= @label %></span>
    <% end %>
    """
  end

  def modal(assigns) do
    ~H"""
    <div
      class="fixed z-100 inset-0 overflow-y-auto"
      aria-labelledby="modal-title"
      role="dialog"
      aria-modal="true"
    >
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true">
        </div>
        <!-- This element is to trick the browser into centering the modal contents. -->
        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">
          &#8203;
        </span>

        <div
          class="relative inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-xl sm:w-full sm:p-6"
          phx-click-away="close_modal"
          phx-window-keydown="close_modal"
          phx-key="Escape"
          phx-target={@target}
        >
          <div class="hidden sm:block absolute z-50 top-0 right-0 pt-4 pr-4">
            <button
              type="button"
              class="text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-urge-500 p-1"
              phx-click="close_modal"
              phx-target={@target}
              data-confirm={@close_confirmation}
            >
              <span class="sr-only">Close</span>
              <!-- Heroicon name: outline/x -->
              <svg
                class="h-6 w-6"
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end

  def card(assigns) do
    assigns =
      assigns
      |> assign_new(:header, fn -> [] end)
      |> assign_new(:header_classes, fn -> "" end)
      |> assign_new(:no_pad, fn -> false end)

    ~H"""
    <div class="bg-white overflow-hidden shadow rounded-lg divide-y divide-gray-200">
      <%= unless Enum.empty?(@header) do %>
        <div class={"py-4 px-5 sm:py-5 " <> @header_classes}>
          <%= render_slot(@header) %>
        </div>
      <% end %>
      <div class={if @no_pad, do: "", else: "py-4 px-5 sm:py-5"}>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  def notification(assigns) do
    assigns =
      assigns
      |> assign_new(:title, fn -> "" end)
      |> assign_new(:right, fn -> [] end)
      # Forces reflow for new notifications; resets animation
      |> assign_new(:id, fn -> Utils.generate_random_sequence(5) end)

    icon =
      case assigns[:type] do
        _ ->
          ~H"""
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-6 w-6 text-info-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          """
      end

    ~H"""
    <div
      class="max-w-sm w-full bg-white shadow-lg rounded-lg pointer-events-auto ring-1 ring-black ring-opacity-5 overflow-hidden"
      id={@id}
    >
      <div class="p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <%= icon %>
          </div>
          <div class="ml-3 w-0 flex-1 pt-0.5">
            <%= if String.length(@title) > 0 do %>
              <p class="text-sm font-medium text-gray-900 mb-1"><%= @title %></p>
            <% end %>
            <p class="text-sm text-gray-500"><%= render_slot(@inner_block) %></p>
          </div>
          <%= render_slot(@right) %>
        </div>
      </div>
    </div>
    """
  end

  def nav(assigns) do
    ~H"""
    <div class="md:w-28 h-20"></div>
    <div
      class="w-full md:w-28 bg-neutral-700 overflow-y-auto fixed z-50 md:h-screen self-start"
      x-data="{ open: window.innerWidth >= 768 }"
      x-transition
    >
      <div class="w-full pt-6 flex flex-col items-center md:h-full">
        <div class="flex w-full px-4 md:px-0 border-b pb-6 md:pb-0 md:border-0 border-neutral-600 justify-between md:justify-center items-center">
          <%= link to: "/", class: "flex flex-col items-center text-white" do %>
            <span class="text-white text-xl py-px px-1 rounded-sm bg-white text-neutral-700 uppercase font-extrabold font-mono">
              Atlos
            </span>
          <% end %>
          <div>
            <button type="button" class="md:hidden pt-1" x-on:click="open = true" x-show="!open">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6 text-white"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>

            <button type="button" class="md:hidden pt-1" x-on:click="open = false" x-show="open">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6 text-white"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>
        <div
          class="grid md:flex md:flex-col md:justify-start grid-cols-3 gap-1 md:grid-cols-1 mt-6 w-full px-2 md:h-full md:pb-2 pb-6 max-h-full"
          x-show="open"
          x-cloak
        >
          <.navlink to="/new" label="New" request_path={@path}>
            <svg
              class="text-white group-hover:text-white h-6 w-6"
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
            </svg>
          </.navlink>

          <.navlink to="/map" label="Map" request_path={@path}>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="text-neutral-300 group-hover:text-white h-6 w-6"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7"
              />
            </svg>
          </.navlink>

          <.navlink to="/queue" label="Queue" request_path={@path}>
            <svg
              class="text-neutral-300 group-hover:text-white h-6 w-6"
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"
              />
            </svg>
          </.navlink>

          <.navlink to="/media" label="All Media" request_path={@path}>
            <svg
              class="text-neutral-300 group-hover:text-white h-6 w-6"
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
              />
            </svg>
          </.navlink>

          <.navlink to="/subscriptions" label="Subscriptions" request_path={@path}>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="text-neutral-300 group-hover:text-white h-6 w-6"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
              />
            </svg>
          </.navlink>
          <div class="hidden md:block flex-grow"></div>
          <%= if not is_nil(@current_user) do %>
            <.navlink to="/settings" label="Account" request_path={@path}>
              <img
                class="relative z-30 inline-block h-6 w-6 rounded-full ring-2 ring-neutral-300"
                src={Accounts.get_profile_photo_path(@current_user)}
                title="Your profile photo"
                alt={"Profile photo for #{@current_user.username} (you)"}
              />
            </.navlink>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def stepper(%{options: options, active: active} = assigns) do
    active_index = Enum.find_index(options, &String.equivalent?(&1, active))

    ~H"""
    <nav aria-label="Progress">
      <ol
        role="list"
        class="border border-gray-300 rounded-md divide-y divide-gray-300 md:flex md:divide-y-0 bg-white"
      >
        <%= for {item, index} <- Enum.with_index(options) do %>
          <li class="relative md:flex-1 md:flex">
            <%= if index < active_index do %>
              <!-- Completed Step -->
              <div class="group flex items-center w-full">
                <span class="px-6 py-4 flex items-center text-sm font-medium">
                  <span class="flex-shrink-0 w-10 h-10 flex items-center justify-center bg-urge-600 rounded-full ">
                    <!-- Heroicon name: solid/check -->
                    <svg
                      class="w-6 h-6 text-white"
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 20 20"
                      fill="currentColor"
                      aria-hidden="true"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                        clip-rule="evenodd"
                      />
                    </svg>
                  </span>
                  <span class="ml-4 text-sm font-medium text-gray-900"><%= item %></span>
                </span>
              </div>
            <% end %>

            <%= if index == active_index do %>
              <!-- Current Step -->
              <div class="px-6 py-4 flex items-center text-sm font-medium" aria-current="step">
                <span class="flex-shrink-0 w-10 h-10 flex items-center justify-center border-2 border-urge-600 rounded-full">
                  <span class="text-urge-600"><%= index + 1 %></span>
                </span>
                <span class="ml-4 text-sm font-medium text-urge-600"><%= item %></span>
              </div>
            <% end %>

            <%= if index > active_index do %>
              <!-- Upcoming Step -->
              <div class="group flex items-center">
                <span class="px-6 py-4 flex items-center text-sm font-medium">
                  <span class="flex-shrink-0 w-10 h-10 flex items-center justify-center border-2 border-gray-300 rounded-full">
                    <span class="text-gray-500"><%= index + 1 %></span>
                  </span>
                  <span class="ml-4 text-sm font-medium text-gray-500"><%= item %></span>
                </span>
              </div>
            <% end %>

            <%= if index != length(options) - 1 do %>
              <!-- Arrow separator for lg screens and up -->
              <div class="hidden md:block absolute top-0 right-0 h-full w-5" aria-hidden="true">
                <svg
                  class="h-full w-full text-gray-300"
                  viewBox="0 0 22 80"
                  fill="none"
                  preserveAspectRatio="none"
                >
                  <path
                    d="M0 -2L20 40L0 82"
                    vector-effect="non-scaling-stroke"
                    stroke="currentcolor"
                    stroke-linejoin="round"
                  />
                </svg>
              </div>
            <% end %>
          </li>
        <% end %>
      </ol>
    </nav>
    """
  end

  def naive_pluralise(amt, word) when amt == 1, do: word
  def naive_pluralise(_amt, word), do: word <> "s"

  defp time_ago_in_words(seconds) when seconds < 60 do
    "just now"
  end

  defp time_ago_in_words(seconds) when seconds < 3600 do
    amt = round(seconds / 60)
    "#{amt} #{naive_pluralise(amt, "minute")} ago"
  end

  defp time_ago_in_words(seconds) when seconds < 86400 do
    amt = round(seconds / 3600)
    "#{amt} #{naive_pluralise(amt, "hour")} ago"
  end

  defp time_ago_in_words(seconds) do
    amt = round(seconds / 86400)
    "#{amt} #{naive_pluralise(amt, "day")} ago"
  end

  defp seconds_ago(datetime) do
    {start, _} = DateTime.to_gregorian_seconds(DateTime.utc_now())
    {now, _} = DateTime.to_gregorian_seconds(DateTime.from_naive!(datetime, "Etc/UTC"))
    start - now
  end

  def rel_time(%{time: time} = assigns) when is_nil(time) do
    ~H"""
    <span>Never</span>
    """
  end

  def rel_time(%{time: time} = assigns) do
    ago = time |> seconds_ago()

    months = %{
      1 => "Jan",
      2 => "Feb",
      3 => "Mar",
      4 => "Apr",
      5 => "May",
      6 => "Jun",
      7 => "Jul",
      8 => "Aug",
      9 => "Sep",
      10 => "Oct",
      11 => "Nov",
      12 => "Dec"
    }

    if ago > 7 * 24 * 60 * 60 do
      ~H"""
      <span title={@time}><%= months[@time.month] %> <%= @time.day %> <%= @time.year %></span>
      """
    else
      ~H"""
      <span title={@time}><%= ago |> time_ago_in_words() %></span>
      """
    end
  end

  def location(%{lat: lat, lon: lon} = assigns) do
    ~H"""
    <%= lat %>, <%= lon %> &nearr;
    """
  end

  def attr_entry(%{name: name, value: value} = assigns) do
    attr = Attribute.get_attribute(name)

    ~H"""
    <span class="inline-flex flex-wrap gap-1">
      <%= case attr.type do %>
        <% :text -> %>
          <div class="inline-block prose prose-sm my-px">
            <%= raw(value |> Utils.render_markdown()) %>
          </div>
        <% :select -> %>
          <div class="inline-block">
            <div class="chip ~neutral inline-block"><%= value %></div>
          </div>
        <% :multi_select -> %>
          <%= for item <- value do %>
            <div class="chip ~neutral inline-block"><%= item %></div>
          <% end %>
        <% :location -> %>
          <div class="inline-block">
            <% {lon, lat} = value.coordinates %>
            <a
              class="chip ~neutral inline-block flex gap-1"
              target="_blank"
              href={"https://maps.google.com/maps?q=#{lat},#{lon}"}
            >
              <.location lat={lat} lon={lon} />
            </a>
          </div>
        <% :time -> %>
          <div class="inline-block">
            <div class="chip ~neutral inline-block"><%= value %></div>
          </div>
        <% :date -> %>
          <div class="inline-block">
            <div class="chip ~neutral inline-block"><%= value %></div>
          </div>
      <% end %>
    </span>
    """
  end

  def text_diff(%{old: old, new: new} = assigns) do
    old_words = String.split(old || "") |> Enum.map(&String.trim(&1))
    new_words = String.split(new || "") |> Enum.map(&String.trim(&1))
    diff = List.myers_difference(old_words, new_words)

    ~H"""
    <span class="text-sm">
      <%= for {action, elem} <- diff do %>
        <%= for val <- elem do %>
          <%= case action do %>
            <% :ins -> %>
              <span class="px-1 text-blue-800 bg-blue-200 rounded-sm mx-px">
                <%= val %>
              </span>
            <% :del -> %>
              <span class="px-1 text-yellow-800 bg-yellow-200 rounded-sm line-through mx-px">
                <%= val %>
              </span>
            <% :eq -> %>
              <span class="text-gray-700 px-0 text-sm mx-px">
                <%= val %>
              </span>
          <% end %>
        <% end %>
      <% end %>
    </span>
    """
  end

  def list_diff(%{old: old, new: new} = assigns) do
    clean = fn x ->
      cleaned = if is_nil(x), do: [], else: x
      cleaned |> Enum.filter(&(!(is_nil(&1) || &1 == ""))) |> Enum.sort()
    end

    diff = List.myers_difference(clean.(old), clean.(new))

    ~H"""
    <span class="flex flex-wrap gap-1">
      <%= for {action, elem} <- diff do %>
        <%= case action do %>
          <% :eq -> %>
            <%= for item <- elem do %>
              <span class="chip ~neutral inline-block text-xs">
                <%= item %>
              </span>
            <% end %>
          <% :ins -> %>
            <%= for item <- elem do %>
              <span class="chip ~blue inline-block text-xs">
                + <%= item %>
              </span>
            <% end %>
          <% :del -> %>
            <%= for item <- elem do %>
              <span class="chip ~yellow inline-block text-xs">
                - <%= item %>
              </span>
            <% end %>
        <% end %>
      <% end %>
    </span>
    """
  end

  def location_diff(%{old: old, new: new} = assigns) do
    ~H"""
    <span>
      <%= case old do %>
        <% %{"coordinates" => [lon, lat]} -> %>
          <a
            class="chip ~yellow inline-flex text-xs"
            target="_blank"
            href={"https://maps.google.com/maps?q=#{lat},#{lon}"}
          >
            -
            <.location lat={lat} lon={lon} />
          </a>
        <% _x -> %>
      <% end %>
      <%= case new do %>
        <% %{"coordinates" => [lon, lat]} -> %>
          <a
            class="chip ~blue inline-flex text-xs"
            target="_blank"
            href={"https://maps.google.com/maps?q=#{lat},#{lon}"}
          >
            +
            <.location lat={lat} lon={lon} />
          </a>
        <% _x -> %>
      <% end %>
    </span>
    """
  end

  def attr_diff(%{name: name, old: old, new: new} = assigns) do
    attr = Attribute.get_attribute(name)

    ~H"""
    <span>
      <%= case attr.type do %>
        <% :text -> %>
          <.text_diff old={old} new={new} />
        <% :select -> %>
          <.list_diff old={[old]} new={[new]} />
        <% :multi_select -> %>
          <.list_diff old={old} new={new} />
        <% :location -> %>
          <.location_diff old={old} new={new} />
        <% :time -> %>
          <.list_diff old={[old]} new={[new]} />
        <% :date -> %>
          <.list_diff old={[old]} new={[new]} />
      <% end %>
    </span>
    """
  end

  def deconfliction_warning(%{duplicates: duplicates, current_user: current_user} = assigns) do
    ~H"""
    <div class="p-4 mt-4 rounded bg-gray-100 transition-all">
      <p class="text-sm">
        Note that media at this URL has already been uploaded. While you can still upload the media, take care to ensure it is not a duplicate.
      </p>
      <div class="grid grid-cols-1 gap-4 mt-4">
        <%= for dupe <- duplicates do %>
          <.media_card media={dupe.media} current_user={current_user} />
        <% end %>
      </div>
    </div>
    """
  end

  def media_card(%{media: %Media{} = media, current_user: %Accounts.User{} = user} = assigns) do
    # TODO: preload
    contributors = Material.contributors(media)
    sensitive = Media.is_sensitive(media)

    ~H"""
    <a
      class="flex items-stretch group flex-row bg-white overflow-hidden shadow rounded-lg justify-between min-h-32 max-h-48"
      href={"/media/#{media.slug}"}
    >
      <%= if Media.can_user_view(media, user) do %>
        <div class="h-full p-2 flex flex-col w-3/4 gap-2">
          <section>
            <p class="font-mono text-xs text-gray-500"><%= media.slug %></p>
            <p class="text-gray-900 group-hover:text-gray-900">
              <%= media.description |> Utils.truncate(80) %>
            </p>
          </section>
          <section class="flex flex-wrap gap-1 self-start align-top">
            <%= if sensitive do %>
              <%= for item <- media.attr_sensitive || [] do %>
                <span class="badge ~critical">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-3 w-3 mr-px"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                      clip-rule="evenodd"
                    />
                  </svg>

                  <%= item %>
                </span>
              <% end %>
            <% end %>

            <%= for item <- media.attr_restrictions || [] do %>
              <span class="badge ~warning">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-3 w-3 mr-px"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"
                  />
                </svg>
                <%= item %>
              </span>
            <% end %>

            <%= if media.attr_flag do %>
              <span class="badge ~urge">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-3 w-3 mr-px"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path
                    fill-rule="evenodd"
                    d="M3 6a3 3 0 013-3h10a1 1 0 01.8 1.6L14.25 8l2.55 3.4A1 1 0 0116 13H6a1 1 0 00-1 1v3a1 1 0 11-2 0V6z"
                    clip-rule="evenodd"
                  />
                </svg>
                <%= media.attr_flag %>
              </span>
            <% end %>

            <%= if media.attr_geolocation do %>
              <span class="badge ~neutral">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-3 w-3 mr-px"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path
                    fill-rule="evenodd"
                    d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z"
                    clip-rule="evenodd"
                  />
                </svg>
                Geolocated
              </span>
            <% end %>

            <%= if media.attr_date_recorded do %>
              <span class="badge ~neutral">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-3 w-3 mr-px"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z"
                    clip-rule="evenodd"
                  />
                </svg>
                <%= media.attr_date_recorded %>
              </span>
            <% end %>

            <span class="badge ~neutral">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-3 w-3 mr-px"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path d="M3 12v3c0 1.657 3.134 3 7 3s7-1.343 7-3v-3c0 1.657-3.134 3-7 3s-7-1.343-7-3z" />
                <path d="M3 7v3c0 1.657 3.134 3 7 3s7-1.343 7-3V7c0 1.657-3.134 3-7 3S3 8.657 3 7z" />
                <path d="M17 5c0 1.657-3.134 3-7 3S3 6.657 3 5s3.134-3 7-3 7 1.343 7 3z" />
              </svg>
              <%= length(Attribute.set_for_media(media)) %> Attrs
            </span>

            <span class="badge ~neutral">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-3 w-3 mr-px"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path d="M2 5a2 2 0 012-2h7a2 2 0 012 2v4a2 2 0 01-2 2H9l-3 3v-3H4a2 2 0 01-2-2V5z" />
                <path d="M15 7v2a4 4 0 01-4 4H9.828l-1.766 1.767c.28.149.599.233.938.233h2l3 3v-3h2a2 2 0 002-2V9a2 2 0 00-2-2h-1z" />
              </svg>
              <%= length(media.updates) %> Updates
            </span>
          </section>
          <section class="flex-grow" />
          <section class="flex gap-2 justify-between items-center">
            <.user_stack users={contributors} />
            <p class="text-xs text-gray-500 flex items-center">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4 mr-px text-gray-400"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z"
                  clip-rule="evenodd"
                />
              </svg>
              <.rel_time time={media.updated_at} />
            </p>
          </section>
        </div>

        <% thumb = Material.media_thumbnail(media) %>
        <div class="block h-full w-1/4 grayscale self-stretch overflow-hidden">
          <%= if thumb do %>
            <%= if Media.is_graphic(media) do %>
              <div class="bg-gray-200 flex items-center justify-around h-48 w-full text-gray-500">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-8 w-8"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"
                  />
                </svg>
              </div>
            <% else %>
              <img class="sr-hide object-cover h-48 overflow-hidden w-full" src={thumb} />
            <% end %>
          <% else %>
            <div class="bg-gray-200 flex items-center justify-around h-48 w-full text-gray-500">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-8 w-8"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="relative block border-2 border-gray-300 border-dashed rounded-lg h-full w-full text-center flex flex-col justify-center">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="mx-auto h-12 w-12 text-gray-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"
            />
          </svg>
          <span class="mt-2 block text-sm font-medium text-gray-700">Hidden or Unavailable</span>
        </div>
      <% end %>
    </a>
    """
  end

  def user_stack(assigns) do
    ~H"""
    <div class="flex -space-x-1 relative z-0 overflow-hidden">
      <%= for user <- @users |> Enum.take(5) do %>
        <img
          class="relative z-30 inline-block h-6 w-6 rounded-full ring-2 ring-white"
          src={Accounts.get_profile_photo_path(user)}
          title={user.username}
          alt={"Profile photo for #{user.username}"}
        />
      <% end %>
      <%= if length(@users) > 5 do %>
        <div class="bg-gray-300 text-gray-700 text-xl rounded-full h-6 w-6 z-30 ring-2 ring-white flex items-center justify-center">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-4 w-4"
            viewBox="0 0 20 20"
            fill="currentColor"
          >
            <path
              fill-rule="evenodd"
              d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z"
              clip-rule="evenodd"
            />
          </svg>
        </div>
      <% end %>
    </div>
    """
  end

  def dropdown(assigns) do
    ~H"""
    <div class="relative inline-block text-left">
      <div>
        <button
          type="button"
          class="inline-flex justify-center w-full rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-100 focus:ring-urge-500"
          phx-click={
            JS.toggle(
              to: "##{@id}",
              in:
                {"transition ease-out duration-100", "transform opacity-0 scale-95",
                 "transform opacity-100 scale-100"},
              out:
                {"transition ease-in duration-75", "transform opacity-100 scale-100",
                 "transform opacity-0 scale-95"}
            )
          }
          id={"#{@id}-button"}
          aria-haspopup="true"
        >
          <%= @label %>

          <svg
            class="-mr-1 ml-2 h-5 w-5"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z"
              clip-rule="evenodd"
            />
          </svg>
        </button>
      </div>

      <div
        class="z-10 hidden origin-top-right absolute right-0 mt-2 w-48 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 flex flex-col gap-4 focus:outline-none overflow-hidden"
        role="menu"
        aria-orientation="vertical"
        aria-labelledby={"##{@id}-button"}
        tabindex="-1"
        id={"#{@id}"}
      >
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  def media_version_display(
        %{version: version, blur: _blur, current_user: current_user, media: media} = assigns
      ) do
    # TODO: real blurring

    media_to_show = version.status == :complete

    ~H"""
    <section id={"version-#{version.id}"}>
      <% loc = Material.media_version_location(version, media) %>
      <% media_id = "version-#{version.id}-media" %>
      <div class="relative">
        <%= if media_to_show do %>
          <div class={if version.hidden, do: "opacity-25 grayscale", else: "grayscale"} id={media_id}>
            <%= if String.starts_with?(version.mime_type, "image/") do %>
              <img src={loc} class="w-full" />
            <% else %>
              <video controls preload="metadata" muted>
                <source src={loc} class="w-full" />
              </video>
            <% end %>
          </div>
        <% else %>
          <div class="w-full h-40 bg-neutral-50 border rounded-lg flex items-center justify-around">
            <%= if version.status == :pending do %>
              <div class="text-center w-48">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="mx-auto h-8 w-8 text-gray-400 animate-pulse"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M9 19l3 3m0 0l3-3m-3 3V10"
                  />
                </svg>
                <h3 class="mt-2 font-medium text-gray-900 text-sm">Processing</h3>
                <p class="mt-1 text-gray-500 text-sm">
                  Archival in progress. Check back soon.
                </p>
                <a
                  target="_blank"
                  href={version.source_url}
                  rel="nofollow"
                  class="button mt-1 original py-1 px-2 text-xs"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4 text-neutral-500 mr-1"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z" />
                    <path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z" />
                  </svg>
                  View Directly
                </a>
              </div>
            <% else %>
              <div class="text-center w-48">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="mx-auto h-8 w-8 text-critical-600"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                  />
                </svg>
                <h3 class="mt-2 font-medium text-gray-900 text-sm">Unable to Archive</h3>
                <p class="mt-1 text-gray-500 text-sm">
                  Automatic archival failed. Please upload manually.
                </p>
                <a
                  target="_blank"
                  href={version.source_url}
                  rel="nofollow"
                  class="button mt-1 original py-1 px-2 text-xs"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4 text-neutral-500 mr-1"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z" />
                    <path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z" />
                  </svg>
                  View Directly
                </a>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      <div class="flex gap-1 mt-1 text-xs max-w-full flex-wrap">
        <%= if media_to_show do %>
          <a
            target="_blank"
            href={version.source_url}
            rel="nofollow"
            class="button original py-1 px-2"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 text-neutral-500 mr-1"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z" />
              <path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z" />
            </svg>
            Source
          </a>
          <a target="_blank" href={loc} rel="nofollow" class="button original py-1 px-2">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 text-neutral-500 mr-1"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
              />
            </svg>
            Download
          </a>
          <button
            type="button"
            rel="nofollow"
            class="button original py-1 px-2"
            onclick={"toggleClass('#{media_id}', 'grayscale')"}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 text-neutral-500 mr-1"
              viewBox="0 0 20 20"
              fill="currentColor"
            >
              <path
                fill-rule="evenodd"
                d="M3.707 2.293a1 1 0 00-1.414 1.414l14 14a1 1 0 001.414-1.414l-1.473-1.473A10.014 10.014 0 0019.542 10C18.268 5.943 14.478 3 10 3a9.958 9.958 0 00-4.512 1.074l-1.78-1.781zm4.261 4.26l1.514 1.515a2.003 2.003 0 012.45 2.45l1.514 1.514a4 4 0 00-5.478-5.478z"
                clip-rule="evenodd"
              />
              <path d="M12.454 16.697L9.75 13.992a4 4 0 01-3.742-3.741L2.335 6.578A9.98 9.98 0 00.458 10c1.274 4.057 5.065 7 9.542 7 .847 0 1.669-.105 2.454-.303z" />
            </svg>
            Toggle Color
          </button>
        <% end %>
        <%= if Accounts.is_privileged(current_user) do %>
          <button
            type="button"
            data-confirm="Are you sure you want to change the visibility of this version?"
            class="button original py-1 px-2 text-critical-800 border-critical-200"
            phx-click="toggle_media_visibility"
            phx-value-version={version.id}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 mr-1"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"
              />
            </svg>
            <%= if version.hidden, do: "Unhide", else: "Hide" %>
          </button>
        <% end %>
      </div>
    </section>
    """
  end

  def user_text(%{user: %Accounts.User{} = user} = assigns) do
    ~H"""
    <a
      class="font-medium text-gray-900 hover:text-urge-600 inline-flex gap-1 flex-wrap"
      href={"/profile/#{user.username}"}
    >
      <%= user.username %>
      <%= if Accounts.is_admin(user) do %>
        <span class="font-normal text-xs badge ~critical self-center">Admin</span>
      <% end %>
      <%= if String.length(user.flair) > 0 do %>
        <span class="font-normal text-xs badge ~urge self-center"><%= user.flair %></span>
      <% end %>
    </a>
    """
  end

  def floating_warning(assigns) do
    ~H"""
    <section class="fixed bottom-0 inset-x-0 pb-2 sm:pb-5">
      <div class="max-w-7xl mx-auto px-2 sm:px-6 lg:px-8">
        <div class="p-2 rounded-lg bg-critical-600 shadow-lg sm:p-3">
          <div class="flex items-center justify-between flex-wrap">
            <div class="w-0 flex-1 flex items-center">
              <span class="flex p-2 rounded-lg bg-critical-800">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-6 w-6 text-white"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                  />
                </svg>
              </span>
              <p class="ml-3 font-medium text-white">
                <%= render_slot(@inner_block) %>
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def hcaptcha(assigns) do
    site_key = System.get_env("HCAPTCHA_SITE_KEY")

    ~H"""
    <article>
      <div
        id="hcaptcha-demo"
        class="h-captcha"
        data-sitekey={site_key}
        data-callback="onSuccess"
        data-expired-callback="onExpire"
      >
      </div>
      <script src="https://js.hcaptcha.com/1/api.js?hl=en" async defer>
      </script>
    </article>
    """
  end
end
