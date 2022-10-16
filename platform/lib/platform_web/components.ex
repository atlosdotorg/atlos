defmodule PlatformWeb.Components do
  use Phoenix.Component
  use Phoenix.HTML
  import Phoenix.View
  import PlatformWeb.ErrorHelpers

  alias Platform.Accounts
  alias Platform.Material.Attribute
  alias Platform.Material.Media
  alias Platform.Material
  alias Platform.Utils
  alias Platform.Notifications
  alias Platform.Uploads
  alias PlatformWeb.Router.Helpers, as: Routes

  def navlink(%{request_path: path, to: to} = assigns) do
    active = String.starts_with?(path, to) and !String.equivalent?(path, "/")

    classes =
      if active do
        "self-start bg-neutral-800 text-white group w-full p-3 rounded-md flex flex-col items-center text-xs font-medium"
      else
        "self-start text-neutral-100 hover:bg-neutral-800 hover:text-white group w-full p-3 rounded-md flex flex-col items-center text-xs font-medium"
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
      class="fixed z-[10000] inset-0 overflow-y-auto"
      aria-labelledby="modal-title"
      role="dialog"
      aria-modal="true"
      phx-hook="Modal"
      id="modal"
      x-data
    >
      <div
        class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0"
        @keydown.escape="window.closeModal($event)"
        phx-target={@target}
      >
        <div
          class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
          aria-hidden="true"
          x-on:click="window.closeModal($event)"
          phx-target={@target}
        >
        </div>
        <!-- This element is to trick the browser into centering the modal contents. -->
        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">
          &#8203;
        </span>

        <div class="relative inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-xl sm:w-full sm:p-6">
          <div class="hidden sm:block absolute z-50 top-0 right-0 pt-4 pr-4">
            <button
              type="button"
              class="text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-urge-500 p-1"
              x-on:click="window.closeModal($event)"
              phx-target={@target}
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
      |> assign_new(:header_class, fn -> "" end)
      |> assign_new(:class, fn -> "" end)
      |> assign_new(:no_pad, fn -> false end)

    ~H"""
    <div class={
      "bg-white shadow rounded-lg divide-y divide-gray-200 " <>
        @class
    }>
      <%= unless Enum.empty?(@header) do %>
        <div class={"py-4 px-5 sm:py-5 " <> @header_class}>
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
        "security" ->
          ~H"""
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="currentColor"
            class="w-6 h-6 text-purple-400"
          >
            <path
              fill-rule="evenodd"
              d="M11.484 2.17a.75.75 0 011.032 0 11.209 11.209 0 007.877 3.08.75.75 0 01.722.515 12.74 12.74 0 01.635 3.985c0 5.942-4.064 10.933-9.563 12.348a.749.749 0 01-.374 0C6.314 20.683 2.25 15.692 2.25 9.75c0-1.39.223-2.73.635-3.985a.75.75 0 01.722-.516l.143.001c2.996 0 5.718-1.17 7.734-3.08zM12 8.25a.75.75 0 01.75.75v3.75a.75.75 0 01-1.5 0V9a.75.75 0 01.75-.75zM12 15a.75.75 0 00-.75.75v.008c0 .414.336.75.75.75h.008a.75.75 0 00.75-.75v-.008a.75.75 0 00-.75-.75H12z"
              clip-rule="evenodd"
            />
          </svg>
          """

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
    name = Utils.get_instance_name()
    version = Utils.get_instance_version()
    runtime = Utils.get_runtime_information()

    ~H"""
    <div class="md:w-28 h-20"></div>
    <div
      class="w-full md:w-28 bg-neutral-700 overflow-y-auto fixed z-50 md:h-screen self-start"
      x-data="{ open: window.innerWidth >= 768 }"
      x-transition
    >
      <div class="w-full pt-6 flex flex-col items-center md:h-full">
        <div class="flex w-full px-4 md:px-0 border-b pb-6 md:pb-0 md:border-0 border-neutral-600 justify-between md:justify-center items-center">
          <%= link to: "/", class: "flex gap-2 md:gap-0 md:flex-col items-center text-white", title: "Atlos version #{version} (runtime: #{runtime})" do %>
            <span class="text-xl py-px px-1 rounded-sm bg-white text-neutral-700 uppercase font-extrabold font-mono">
              Atlos
            </span>
            <%= if not is_nil(name) do %>
              <span class="font-mono md:text-sm uppercase font-medium text-xl md:mt-1">
                <%= name %>
              </span>
            <% end %>
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
          class="grid md:flex md:flex-col md:justify-start grid-cols-3 gap-1 md:grid-cols-1 mt-6 w-full px-2 md:h-full md:pb-2 pb-6 md:max-h-full"
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

          <.navlink to="/incidents" label="Incidents" request_path={@path}>
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

          <.navlink to="/notifications" label="Notifications" request_path={@path}>
            <div class="relative">
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
                  d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
                />
              </svg>
              <%= if Notifications.has_unread_notifications(@current_user) do %>
                <% active = String.starts_with?(@path, "/notifications") %>
                <div class={"text-urge-400 absolute top-[3px] right-[3px] rounded-full ring-2 group-hover:ring-neutral-800 " <> (if active, do: "ring-neutral-800", else: "ring-neutral-700")}>
                  <svg
                    viewBox="0 0 100 100"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="currentColor"
                    class="h-2 w-2"
                  >
                    <circle cx="50" cy="50" r="50" />
                  </svg>
                </div>
              <% end %>
            </div>
          </.navlink>
          <%= if !is_nil(@current_user) and Accounts.is_admin(@current_user) do %>
            <.navlink to="/adminland" label="Adminland" request_path={@path}>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="text-neutral-300 group-hover:text-white h-6 w-6"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M10.496 2.132a1 1 0 00-.992 0l-7 4A1 1 0 003 8v7a1 1 0 100 2h14a1 1 0 100-2V8a1 1 0 00.496-1.868l-7-4zM6 9a1 1 0 00-1 1v3a1 1 0 102 0v-3a1 1 0 00-1-1zm3 1a1 1 0 012 0v3a1 1 0 11-2 0v-3zm5-1a1 1 0 00-1 1v3a1 1 0 102 0v-3a1 1 0 00-1-1z"
                  clip-rule="evenodd"
                />
              </svg>
            </.navlink>
          <% end %>
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

  defp connector_language(index, total) do
    cond do
      index == total - 1 -> ""
      true -> ","
    end
  end

  def update_entry(
        %{
          update: update,
          show_line: show_line,
          show_media: show_media,
          can_user_change_visibility: can_user_change_visibility,
          target: target,
          socket: socket,
          left_indicator: indicator,
          current_user: current_user
        } = assigns
      ) do
    profile_ring_classes =
      if Map.get(assigns, :profile_ring, true) do
        "ring-8 ring-white"
      else
        ""
      end

    if is_list(update) do
      [head | _] = update

      attributes =
        update
        |> Enum.map(&Attribute.get_attribute(&1.modified_attribute))
        |> Enum.sort()
        |> Enum.uniq()

      n_attributes = length(attributes)

      ~H"""
      <li x-data="{expanded: false}" id={"collapsed-update-#{head.id}"}>
        <div
          class="relative pb-8 group word-breaks cursor-pointer"
          x-on:click="expanded = !expanded"
          class="group"
        >
          <%= if show_line do %>
            <span class="absolute top-5 left-5 -ml-px h-full w-0.5 bg-gray-200" aria-hidden="true">
            </span>
          <% end %>
          <div class="relative flex items-start space-x-2">
            <%= if indicator == :profile do %>
              <div class="relative">
                <a href={"/profile/#{head.user.username}"}>
                  <img
                    class={"h-10 w-10 rounded-full bg-gray-400 flex items-center justify-center shadow " <> profile_ring_classes}
                    src={Accounts.get_profile_photo_path(head.user)}
                    alt={"Profile photo for #{head.user.username}"}
                  />
                </a>
              </div>
            <% end %>
            <div class="min-w-0 flex-1 flex flex-col flex-grow group-hover:bg-gray-100 focus-within:bg-gray-100 rounded px-1 py-2 transition-all mt-1">
              <div class="flex flex-wrap items-center">
                <div class="text-sm text-gray-600 flex-grow">
                  <%= if show_media do %>
                    <.media_text media={head.media} />
                  <% end %>
                  <.user_text user={head.user} />
                  <%= case head.type do %>
                    <% :update_attribute -> %>
                      made <%= length(update) %> updates to
                      <%= for {attr, idx} <- attributes |> Enum.with_index() do %>
                        <span class="font-medium text-gray-800">
                          <%= attr.label <> connector_language(idx, n_attributes) %>
                        </span>
                      <% end %>
                    <% :upload_version -> %>
                      added
                      <span class="font-medium text-gray-800">
                        <%= length(update) %> pieces of media
                      </span>
                  <% end %>
                  <.rel_time time={head.inserted_at} />
                </div>
                <button
                  class="text-sm absolute right-0 text-urge-600 opacity-0 font-medium group-hover:opacity-100 focus:opacity-100 group-focus:opacity-100 transition-all px-2 py-1 bg-gray-100 shadow shadow-gray-100 shadow-xl rounded"
                  x-on:click.stop="expanded = !expanded"
                  type="button"
                  x-html="expanded ? 'Collapse' : 'Expand'"
                >
                </button>
              </div>
            </div>
          </div>
        </div>
        <ul
          class="relative overflow-hidden transition-all ease-out duration-700"
          x-ref="container"
          x-show="expanded"
          x-cloak
        >
          <%= for sub_update <- update |> Enum.reverse() do %>
            <.update_entry
              update={sub_update}
              show_line={true}
              show_media={false}
              can_user_change_visibility={can_user_change_visibility}
              target={target}
              socket={socket}
              left_indicator={:dot}
              current_user={current_user}
            />
          <% end %>
        </ul>
      </li>
      """
    else
      ~H"""
      <li class={if update.hidden, do: "opacity-50", else: ""}>
        <div class="relative pb-8 group word-breaks">
          <%= if show_line do %>
            <span class="absolute top-5 left-5 -ml-px h-full w-0.5 bg-gray-200" aria-hidden="true">
            </span>
          <% end %>
          <div class="relative flex items-start space-x-2">
            <%= case indicator do %>
              <% :profile -> %>
                <div class="relative">
                  <a href={"/profile/#{update.user.username}"}>
                    <img
                      class={"h-10 w-10 rounded-full bg-gray-400 flex items-center justify-center " <> profile_ring_classes}
                      src={Accounts.get_profile_photo_path(update.user)}
                      alt={"Profile photo for #{update.user.username}"}
                    />
                  </a>
                </div>
              <% :dot -> %>
                <div class="relative ml-[0.90em] mt-3 mr-4">
                  <svg viewBox="0 0 100 100" class="h-3 w-3 bg-white text-gray-400">
                    <circle cx="50" cy="50" r="40" stroke-width="3" fill="currentColor" />
                  </svg>
                </div>
              <% _ -> %>
            <% end %>
            <div class="min-w-0 flex-1 flex flex-col flex-grow pl-1">
              <div>
                <div class="text-sm text-gray-600 mt-2">
                  <%= if show_media do %>
                    <.media_text media={update.media} />
                  <% end %>
                  <.user_text user={update.user} />
                  <%= case update.type do %>
                    <% :update_attribute -> %>
                      <% attr = Attribute.get_attribute(update.modified_attribute) %> updated
                      <%= live_patch class: "text-button text-gray-800 inline-block", to: Routes.media_show_path(socket, :history, update.media.slug, attr.name) do %>
                        <%= attr.label %> &nearr;
                      <% end %>
                    <% :create -> %>
                      added <span class="font-medium text-gray-900"><%= update.media.slug %></span>
                    <% :upload_version -> %>
                      added
                      <a
                        href={
                          Routes.media_show_path(socket, :show, update.media.slug) <>
                            "#version-#{update.media_version.id}"
                        }
                        class="text-button text-gray-800"
                      >
                        Media &nearr;
                      </a>
                    <% :comment -> %>
                      commented
                  <% end %>
                  <.rel_time time={update.inserted_at} />
                  <%= if update.hidden do %>
                    <span class="badge ~neutral">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-3 w-3 mr-1"
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
                      Hidden
                    </span>
                  <% end %>
                  <%= if can_user_change_visibility do %>
                    <button
                      type="button"
                      phx-target={target}
                      phx-click="change_visibility"
                      phx-value-update={update.id}
                      class="opacity-0 group-hover:opacity-100 text-critical-700 transition text-xs ml-2"
                      data-confirm="Are you sure you want to change the visibility of this update?"
                    >
                      <%= if update.hidden, do: "Show", else: "Hide" %>
                    </button>
                  <% end %>
                </div>
              </div>

              <%= if update.type == :update_attribute || update.explanation do %>
                <div class="mt-1 text-sm text-gray-700 border border-gray-300 rounded-lg shadow-sm overflow-hidden flex flex-col divide-y">
                  <!-- Update detail section -->
                  <%= if update.type == :update_attribute do %>
                    <div class="bg-gray-50 p-2 flex">
                      <div class="flex-grow">
                        <.attr_diff
                          name={update.modified_attribute}
                          old={Jason.decode!(update.old_value)}
                          new={Jason.decode!(update.new_value)}
                        />
                      </div>
                    </div>
                  <% end %>
                  <!-- Text comment section -->
                  <%= if update.explanation do %>
                    <article class="prose text-sm p-2 w-full max-w-full bg-white">
                      <%= raw(update.explanation |> Platform.Utils.render_markdown()) %>
                    </article>
                  <% end %>

                  <%= if not Enum.empty?(update.attachments) do %>
                    <div class="p-2 grid grid-cols-2 md:grid-cols-3 gap-2">
                      <%= for {attachment, idx} <- update.attachments |> Enum.with_index() do %>
                        <% url =
                          Uploads.UpdateAttachment.url({attachment, update.media}, :original,
                            signed: true,
                            expires_in: 60 * 60 * 6
                          ) %>
                        <a
                          class="rounded overflow-hidden max-h-64 cursor-zoom-in"
                          href={url}
                          target="_blank"
                        >
                          <%= if String.ends_with?(attachment, ".jpg") || String.ends_with?(attachment, ".jpeg") || String.ends_with?(attachment, ".png") do %>
                            <img src={url} />
                          <% else %>
                            <.document_preview
                              file_name={"Attachment #" <> to_string(idx + 1)}
                              description="PDF Document"
                            />
                          <% end %>
                        </a>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </li>
      """
    end
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

    full_display_time = Calendar.strftime(time, "%d %B %Y at %H:%M UTC")

    if ago > 7 * 24 * 60 * 60 do
      ~H"""
      <span data-tooltip={full_display_time}>
        <%= months[@time.month] %> <%= @time.day %> <%= @time.year %>
      </span>
      """
    else
      ~H"""
      <span data-tooltip={full_display_time}><%= ago |> time_ago_in_words() %></span>
      """
    end
  end

  def location(%{lat: lat, lon: lon} = assigns) do
    ~H"""
    <%= lat %>, <%= lon %> &nearr;
    """
  end

  def attr_display_block(
        %{
          set_attrs: set_attrs,
          unset_attrs: _unset_attrs,
          media: %Media{} = media,
          updates: updates,
          socket: socket,
          current_user: current_user
        } = assigns
      ) do
    ~H"""
    <dl class="divide-y divide-dashed divide-gray-200 -mt-5 -mb-3 overflow-hidden">
      <%= for attr <- set_attrs do %>
        <.attr_display_row
          attr={attr}
          updates={updates}
          media={media}
          socket={socket}
          current_user={current_user}
          immutable={Map.get(assigns, :immutable, false)}
        />
      <% end %>
      <%= if length(@unset_attrs) > 0 do %>
        <div class="py-2 sm:grid sm:grid-cols-3 sm:gap-4 -mb-2">
          <dt class="text-sm font-medium text-gray-500 mt-1">Add Attributes</dt>
          <dd class="mt-1 flex flex-wrap gap-2 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
            <%= for attr <- @unset_attrs do %>
              <%= live_patch("+ #{attr.label}",
                class: "button original",
                to: Routes.media_show_path(socket, :edit, @media.slug, attr.name)
              ) %>
            <% end %>
          </dd>
        </div>
      <% end %>
    </dl>
    """
  end

  def url_icon(%{url: url, class: classes} = assigns) do
    parsed = URI.parse(url)
    loc = "https://s2.googleusercontent.com/s2/favicons?domain=#{parsed.host}&sz=256"

    ~H"""
    <img src={loc} class={"rounded " <> classes} />
    """
  end

  def attr_display_compact(
        %{
          attr: %Attribute{} = attr,
          media: %Media{} = media,
          current_user: current_user
        } = assigns
      ) do
    children = Attribute.get_children(attr.name)

    ~H"""
    <div class="inline">
      <%= if not is_nil(Map.get(media, attr.schema_field)) and Map.get(media, attr.schema_field) != [] and Map.get(media, attr.schema_field) != "" do %>
        <div class="inline-flex flex-wrap text-xs">
          <div class="break-word max-w-full text-ellipsis overflow-hidden">
            <.attr_entry
              color={true}
              compact={Map.get(assigns, :truncate, true)}
              name={attr.name}
              value={Map.get(media, attr.schema_field)}
            />
            <%= for child <- children do %>
              <%= if not is_nil(Map.get(media, child.schema_field)) do %>
                <.attr_entry
                  color={true}
                  compact={Map.get(assigns, :truncate, true)}
                  name={child.name}
                  value={Map.get(media, child.schema_field)}
                  label={child.label}
                />
              <% end %>
            <% end %>
          </div>
        </div>
      <% else %>
        <span class="text-neutral-400">&mdash;</span>
      <% end %>
    </div>
    """
  end

  def attr_display_row(
        %{
          attr: %Attribute{} = attr,
          media: %Media{} = media,
          updates: updates,
          socket: socket,
          current_user: current_user
        } = assigns
      ) do
    children = Attribute.get_children(attr.name)

    ~H"""
    <div class="py-2 sm:grid sm:grid-cols-3 sm:gap-2">
      <dt class="text-sm font-medium text-gray-500 mt-1 flex justify-between items-center flex-wrap">
        <span class="flex items-center gap-1">
          <%= attr.label %>
          <%= if Platform.Material.Attribute.requires_privileges_to_edit(attr) do %>
            <span title="Special privileges are required to update this attribute.">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4 text-gray-400"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z"
                  clip-rule="evenodd"
                />
              </svg>
            </span>
          <% end %>
        </span>
        <%= live_patch(class: "text-button inline-block",
            to: Routes.media_show_path(socket, :history, media.slug, attr.name)
          ) do %>
          <.user_stack users={
            updates
            |> Enum.filter(&(&1.modified_attribute == attr.name || &1.type == :create))
            |> Enum.sort_by(& &1.inserted_at)
            |> Enum.map(& &1.user)
            |> Enum.reverse()
            |> Enum.take(1)
          } />
        <% end %>
      </dt>
      <dd class="mt-1 flex items-center text-sm text-gray-900 sm:mt-0 sm:col-span-2">
        <span class="flex-grow gap-1 flex flex-wrap">
          <%= if not is_nil(Map.get(media, attr.schema_field)) do %>
            <.attr_entry name={attr.name} value={Map.get(media, attr.schema_field)} />
            <%= for child <- children do %>
              <%= if not is_nil(Map.get(media, child.schema_field)) do %>
                <.attr_entry
                  name={child.name}
                  value={Map.get(media, child.schema_field)}
                  label={child.label}
                />
              <% end %>
            <% end %>
          <% end %>
        </span>
        <span class="ml-4 flex-shrink-0">
          <%= if Attribute.can_user_edit(attr, current_user, media) and not (Map.get(assigns, :immutable, false)) do %>
            <%= live_patch("Update",
              class: "text-button mt-1 inline-block",
              to: Routes.media_show_path(@socket, :edit, media.slug, attr.name)
            ) %>
          <% end %>
        </span>
      </dd>
    </div>
    """
  end

  def security_mode_notifications(assigns) do
    ~H"""
    <%= case Platform.Security.get_security_mode_state() do %>
      <% :read_only -> %>
        <.notification type="security">
          Atlos is in read-only mode. <%= Platform.Security.get_security_mode_description() %>
        </.notification>
      <% :no_access -> %>
        <.notification type="security">
          Atlos is in no-access mode. <%= Platform.Security.get_security_mode_description() %>
        </.notification>
      <% _ -> %>
    <% end %>
    """
  end

  def attr_label(%{label: label} = assigns) do
    ~H"""
    <%= if String.length(label) > 0 do %>
      <span class="opacity-[70%]"><%= label %>:</span>
    <% end %>
    """
  end

  def attr_entry(%{name: name, value: value} = assigns) do
    attr = Attribute.get_attribute(name)

    label = Map.get(assigns, :label, "")
    compact = Map.get(assigns, :compact, false)

    tone =
      if Map.get(assigns, :color, false), do: Attribute.attr_color(name, value), else: "~neutral"

    ~H"""
    <span class="inline-flex flex-wrap gap-1 max-w-full">
      <%= case attr.type do %>
        <% :text -> %>
          <%= if compact do %>
            <div class="inline-block prose prose-sm my-px word-breaks">
              <.attr_label label={label} />
              <%= raw(
                value
                |> String.replace("\n", "")
                |> Utils.truncate(80)
                |> Utils.render_markdown()
              ) %>
            </div>
          <% else %>
            <div class="inline-block prose prose-sm my-px word-breaks">
              <.attr_label label={label} />
              <%= raw(
                value
                |> Utils.render_markdown()
              ) %>
            </div>
          <% end %>
        <% :select -> %>
          <div class="inline-block">
            <div class={"chip #{tone} inline-block self-start break-all xl:break-normal"}>
              <.attr_label label={label} />
              <%= value %>
            </div>
          </div>
        <% :multi_select -> %>
          <.attr_label label={label} />
          <%= for item <- (if compact, do: value |> Enum.take(1), else: value) do %>
            <div class={"chip #{tone} inline-block self-start break-all xl:break-normal"}>
              <%= item %>
            </div>
            <%= if compact and length(value) > 1 do %>
              <div class="text-xs mt-1 text-neutral-500">
                + <%= length(value) - 1 %>
              </div>
            <% end %>
          <% end %>
        <% :location -> %>
          <div class="inline-block">
            <% {lon, lat} = value.coordinates %>
            <a
              class={"chip #{tone} inline-block flex gap-1 self-start break-all xl:break-normal"}
              target="_blank"
              href={"https://maps.google.com/maps?q=#{lat},#{lon}"}
            >
              <.attr_label label={label} />
              <.location lat={lat} lon={lon} />
            </a>
          </div>
        <% :time -> %>
          <div class="inline-block">
            <div class={"chip #{tone} inline-block self-start break-all xl:break-normal"}>
              <.attr_label label={label} />
              <%= value %>
            </div>
          </div>
        <% :date -> %>
          <div class="inline-block">
            <div class={"chip #{tone} inline-block self-start break-all xl:break-normal"}>
              <.attr_label label={label} />
              <%= value |> Calendar.strftime("%d %B %Y") %>
            </div>
          </div>
      <% end %>
    </span>
    """
  end

  def mfa_status(%{user: %Accounts.User{}} = assigns) do
    ~H"""
    <%= if not @user.has_mfa do %>
      <div class="rounded-md bg-red-50 p-4 border border-red-500">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg
              class="h-5 w-5 text-red-400"
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
            >
              <path
                fill-rule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-red-800">
              Multi-factor authentication is not enabled.
            </h3>
          </div>
        </div>
      </div>
    <% else %>
      <div class="rounded-md bg-green-50 p-4 border border-green-500">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg
              class="h-5 w-5 text-green-400"
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
            >
              <path
                fill-rule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-green-800">
              Multi-factor authentication is enabled.
            </h3>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def attr_explanation(%{name: name} = assigns) do
    attr = Attribute.get_attribute(name)

    ~H"""
    <span class="inline-flex flex-wrap gap-1">
      <span class="font-medium">
        <%= attr.name |> to_string() %>
      </span>
      &mdash;
      <%= case attr.type do %>
        <% :text -> %>
          freeform text
        <% :select -> %>
          one of
          <%= for item <- Attribute.options(attr) do %>
            <div class="badge ~urge inline-block"><%= item %></div>
          <% end %>
        <% :multi_select -> %>
          a combination of
          <%= for item <- Attribute.options(attr) do %>
            <div class="badge ~urge inline-block"><%= item %></div>
          <% end %>
          (comma separated)
          <%= if Attribute.allow_user_defined_options(attr) do %>
            (new values allowed)
          <% end %>
        <% :location -> %>
          put latitude in a
          <div class="badge ~urge inline-block">latitude</div>
          column, and longitude in a
          <div class="badge ~urge inline-block">longitude</div>
          column
        <% :time -> %>
          time of day, in the format
          <div class="badge ~urge inline-block">HH:MM:SS</div>
        <% :date -> %>
          date, in the format
          <div class="badge ~urge inline-block">YYYY-MM-DD</div>
      <% end %>
      <%= if attr.required do %>
        (required)
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
      <.attr_label label={Map.get(assigns, :label, "")} />
      <%= for {action, elem} <- diff do %>
        <%= for val <- elem do %>
          <%= case action do %>
            <% :ins -> %>
              <span class="text-blue-800 bg-blue-200">
                <%= val %>
              </span>
            <% :del -> %>
              <span class="text-yellow-800 bg-yellow-200 line-through">
                <%= val %>
              </span>
            <% :eq -> %>
              <span class="text-gray-700 px-0 text-sm">
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
                <.attr_label label={Map.get(assigns, :label, "")} />
                <%= item %>
              </span>
            <% end %>
          <% :ins -> %>
            <%= for item <- elem do %>
              <span class="chip ~blue inline-block text-xs">
                + <.attr_label label={Map.get(assigns, :label, "")} />
                <%= item %>
              </span>
            <% end %>
          <% :del -> %>
            <%= for item <- elem do %>
              <span class="chip ~yellow inline-block text-xs">
                - <.attr_label label={Map.get(assigns, :label, "")} />
                <%= item %>
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
      <%= if old != new do %>
        <%= case old do %>
          <% %{"coordinates" => [lon, lat]} -> %>
            <a
              class="chip ~yellow inline-flex text-xs"
              target="_blank"
              href={"https://maps.google.com/maps?q=#{lat},#{lon}"}
            >
              - <.attr_label label={Map.get(assigns, :label, "")} />
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
              + <.attr_label label={Map.get(assigns, :label, "")} />
              <.location lat={lat} lon={lon} />
            </a>
          <% _x -> %>
        <% end %>
      <% else %>
        <%= case new do %>
          <% %{"coordinates" => [lon, lat]} -> %>
            <a
              class="chip ~neutral inline-flex text-xs"
              target="_blank"
              href={"https://maps.google.com/maps?q=#{lat},#{lon}"}
            >
              <.attr_label label={Map.get(assigns, :label, "")} />
              <.location lat={lat} lon={lon} />
            </a>
          <% _x -> %>
        <% end %>
      <% end %>
    </span>
    """
  end

  def attr_diff(%{name: name, old: old, new: new} = assigns) do
    attr = Attribute.get_attribute(name)
    label = Map.get(assigns, :label, "")
    children = Attribute.get_children(name)

    # It's possible to encode changes to multiple schema fields in one update, but some legacy/existing updates
    # have their values encoded in the old format, so we perform a render-time conversion here.
    old_val =
      if Material.is_combined_update_value(old),
        do: old |> Map.get(attr.schema_field |> to_string()),
        else: old

    new_val =
      if Material.is_combined_update_value(new),
        do: new |> Map.get(attr.schema_field |> to_string()),
        else: new

    format_date = fn val ->
      with false <- is_nil(val),
           {:ok, date} <- val |> Date.from_iso8601() do
        [date |> Calendar.strftime("%d %B %Y")]
      else
        _ -> nil
      end
    end

    ~H"""
    <div class="inline-block">
      <span>
        <%= case attr.type do %>
          <% :text -> %>
            <.text_diff old={old_val} new={new_val} label={label} />
          <% :select -> %>
            <.list_diff old={[old_val]} new={[new_val]} label={label} />
          <% :multi_select -> %>
            <.list_diff
              old={if is_list(old_val), do: old_val, else: [old_val]}
              new={if is_list(new_val), do: new_val, else: [new_val]}
              label={label}
            />
          <% :location -> %>
            <.location_diff old={old_val} new={new_val} label={label} />
          <% :time -> %>
            <.list_diff old={[old_val]} new={[new_val]} label={label} />
          <% :date -> %>
            <.list_diff old={format_date.(old_val)} new={format_date.(new_val)} label={label} />
        <% end %>
      </span>
      <%= if Material.is_combined_update_value(old) and Material.is_combined_update_value(new) do %>
        <%= for child <- children do %>
          <.attr_diff name={child.name} old={old} new={new} label={child.label} />
        <% end %>
      <% end %>
    </div>
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
          <div data-confirm="Open the incident in a new tab? Your current upload won't be affected.">
            <.media_card media={dupe} current_user={current_user} target="_blank" />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def search_form(%{changeset: _, query_params: _, socket: _} = assigns) do
    assigns = assign_new(assigns, :exclude, fn -> [] end)

    ~H"""
    <.form
      :let={f}
      as={:search}
      for={@changeset}
      id="search-form"
      phx-change="validate"
      phx-submit="save"
      class="mb-8"
    >
      <section class="md:flex w-full max-w-7xl mx-auto flex-wrap md:flex-nowrap gap-4 items-center">
        <div class="flex flex-col flex-grow md:flex-row gap-2 rounded-xl p-1 lg:p-4 bg-white shadow">
          <%= if not Enum.member?(@exclude, :query) do %>
            <div class="flex-grow">
              <div class="border border-gray-300 bg-white rounded-md px-3 py-2 shadow-sm focus-within:ring-1 focus-within:ring-urge-600 focus-within:border-urge-600">
                <%= label(f, :query, "Search", class: "block text-xs font-medium text-gray-900") %>
                <%= text_input(f, :query,
                  placeholder: "Enter a query...",
                  phx_debounce: "1000",
                  class:
                    "block w-full border-0 p-0 text-gray-900 placeholder-gray-500 focus:ring-0 sm:text-sm"
                ) %>
              </div>
              <%= error_tag(f, :query) %>
            </div>
          <% end %>
          <%= if not Enum.member?(@exclude, :status) do %>
            <div>
              <div class="ts-ignore border border-gray-300 bg-white rounded-md pl-3 py-2 shadow-sm focus-within:ring-1 focus-within:ring-urge-600 focus-within:border-urge-600">
                <%= label(f, :attr_status, "Status", class: "block text-xs font-medium text-gray-900") %>
                <%= select(
                  f,
                  :attr_status,
                  ["Any"] ++ Attribute.options(Attribute.get_attribute(:status)),
                  class:
                    "block w-full border-0 py-0 pl-0 pr-7 text-gray-900 placeholder-gray-500 focus:ring-0 sm:text-sm"
                ) %>
              </div>
              <%= error_tag(f, :status) %>
            </div>
          <% end %>
          <%= if not Enum.member?(@exclude, :sort) do %>
            <div>
              <div class="ts-ignore border border-gray-300 bg-white rounded-md pl-3 py-2 shadow-sm focus-within:ring-1 focus-within:ring-urge-600 focus-within:border-urge-600">
                <%= label(f, :sort, "Sort", class: "block text-xs font-medium text-gray-900") %>
                <%= select(
                  f,
                  :sort,
                  [
                    "Newest Added": :uploaded_desc,
                    "Oldest Added": :uploaded_asc,
                    "Recently Modified": :modified_desc,
                    "Least Recently Modified": :modified_asc
                  ],
                  class:
                    "block w-full border-0 py-0 pl-0 pr-7 text-gray-900 placeholder-gray-500 focus:ring-0 sm:text-sm"
                ) %>
              </div>
              <%= error_tag(f, :sort) %>
            </div>
          <% end %>
          <%= if not Enum.member?(@exclude, :display) do %>
            <div>
              <div class="ts-ignore border border-gray-300 bg-white rounded-md pl-3 py-2 shadow-sm focus-within:ring-1 focus-within:ring-urge-600 focus-within:border-urge-600">
                <%= label(f, :display, "Display",
                  class: "block text-xs pr-4 font-medium text-gray-900"
                ) %>
                <%= select(
                  f,
                  :display,
                  [
                    Map: :map,
                    Cards: :cards,
                    Table: :table
                  ],
                  class:
                    "block w-full border-0 py-0 pl-0 pr-7 text-gray-900 placeholder-gray-500 focus:ring-0 sm:text-sm"
                ) %>
              </div>
              <%= error_tag(f, :display) %>
            </div>
          <% end %>
          <div class="place-self-center" x-data="{open: false}">
            <div class="relative text-left z-10">
              <div class="h-full">
                <button
                  x-on:click="open = !open"
                  type="button"
                  class="rounded-full flex items-center align-center text-gray-400 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-100 focus:ring-urge-500"
                  id="menu-button"
                  aria-expanded="true"
                  aria-haspopup="true"
                >
                  <span class="sr-only">Open options</span>
                  <!-- Heroicon name: solid/dots-vertical -->
                  <svg
                    class="h-5 w-5"
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                    aria-hidden="true"
                  >
                    <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
                  </svg>
                </button>
              </div>

              <div
                x-show="open"
                x-on:click.outside="open = false"
                x-transition
                x-cloak
                class="origin-top-right absolute right-0 mt-2 w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 focus:outline-none"
                role="menu"
                aria-orientation="vertical"
                aria-labelledby="menu-button"
                tabindex="-1"
              >
                <div class="py-1" role="none">
                  <%= button type: "button", to: Routes.export_path(@socket, :create, @query_params),
                  class: "text-gray-700 group w-full hover:bg-gray-100 flex items-center px-4 py-2 text-sm",
                  role: "menuitem",
                  method: :post
                   do %>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      class="mr-3 h-5 w-5 text-gray-400 group-hover:text-gray-500"
                      viewBox="0 0 20 20"
                      fill="currentColor"
                    >
                      <path
                        fill-rule="evenodd"
                        d="M3 17a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1zm3.293-7.707a1 1 0 011.414 0L9 10.586V3a1 1 0 112 0v7.586l1.293-1.293a1 1 0 111.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z"
                        clip-rule="evenodd"
                      />
                    </svg>
                    Export Results
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </.form>
    """
  end

  def media_card_lazy(%{media: %Media{} = media} = assigns) do
    ~H"""
    <div>
      <div class="fixed w-[350px] h-[190px] flex rounded-lg shadow-lg items-center bg-white justify-around -z-50">
        <div class="font-medium text-lg text-md p-4">
          <span class="animate-pulse">Loading...</span>
        </div>
      </div>
      <iframe dynamic-src={"/incidents/#{media.slug}/card"} width="350px" height="190px" />
    </div>
    """
  end

  def media_card(%{media: %Media{} = media, current_user: %Accounts.User{} = user} = assigns) do
    contributors = Material.contributors(media)
    sensitive = Media.is_sensitive(media)
    assigns = assigns |> Map.put_new(:target, nil)

    border = Map.get(assigns, :border, false)
    link = Map.get(assigns, :link, true)
    class = Map.get(assigns, :class, "")

    ~H"""
    <a
      class={"flex items-stretch group flex-row bg-white overflow-hidden shadow rounded-lg justify-between min-h-[12rem] " <> (if border, do: "border ", else: "") <> class}
      href={if link, do: "/incidents/#{media.slug}", else: nil}
      target={@target}
    >
      <%= if Media.can_user_view(media, user) do %>
        <div class="p-2 flex flex-col w-3/4 gap-2 relative">
          <section>
            <p class="font-mono text-xs text-gray-500 flex items-center gap-1">
              <%= media.slug %>
              <%= if media.has_subscription do %>
                <span data-tooltip="You are subscribed" class="text-neutral-400">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                    class="w-3 h-3"
                  >
                    <path d="M10 12.5a2.5 2.5 0 100-5 2.5 2.5 0 000 5z" />
                    <path
                      fill-rule="evenodd"
                      d="M.664 10.59a1.651 1.651 0 010-1.186A10.004 10.004 0 0110 3c4.257 0 7.893 2.66 9.336 6.41.147.381.146.804 0 1.186A10.004 10.004 0 0110 17c-4.257 0-7.893-2.66-9.336-6.41zM14 10a4 4 0 11-8 0 4 4 0 018 0z"
                      clip-rule="evenodd"
                    />
                  </svg>
                  <span class="sr-only">
                    You are subscribed
                  </span>
                </span>
              <% end %>
              <%= if media.has_unread_notification do %>
                <span data-tooltip="Unread notification" class="text-urge-600">
                  <svg
                    viewBox="0 0 100 100"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="currentColor"
                    class="h-2 w-2"
                  >
                    <circle cx="50" cy="50" r="50" />
                  </svg>
                  <span class="sr-only">
                    Unread notification
                  </span>
                </span>
              <% end %>
            </p>
            <p class="text-gray-900 group-hover:text-gray-900">
              <%= media.attr_description |> Utils.truncate(60) %>
            </p>
          </section>
          <section class="flex flex-wrap gap-1 self-start align-top">
            <%= if media.attr_status do %>
              <span class={"self-start badge " <> Attribute.attr_color(:status, @media.attr_status)}>
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
                <%= media.attr_status %>
              </span>
            <% end %>

            <%= if sensitive do %>
              <%= for item <- media.attr_sensitive || [] do %>
                <span class={"self-start badge " <> Attribute.attr_color(:sensitive, @media.attr_sensitive)}>
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
              <!-- TODO: make this use Attribute.attr_color/2 -->
              <span class="self-start badge ~warning">
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

            <%= if media.attr_geolocation do %>
              <span class="self-start badge ~neutral">
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

            <%= if media.attr_date do %>
              <span class="self-start badge ~neutral">
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
                <%= media.attr_date %>
              </span>
            <% end %>

            <span class="self-start badge ~neutral">
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

            <span class="self-start badge ~neutral">
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
          <section class="mb-2 h-4" />
          <section class="bottom-0 mb-2 pr-4 w-full absolute flex gap-2 justify-between items-center">
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
        <div class="block h-full min-h-[12rem] relative w-1/4 grayscale self-stretch overflow-hidden">
          <%= if thumb do %>
            <%= if Media.is_graphic(media) do %>
              <div class="absolute bg-gray-200 flex items-center justify-around h-full w-full text-gray-500">
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
              <div class="overflow-hidden">
                <img class="absolute sr-hide object-cover min-h-[12rem] h-full w-full" src={thumb} />
              </div>
            <% end %>
          <% else %>
            <div class="absolute bg-gray-200 flex items-center justify-around h-full w-full text-gray-500">
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

  def no_media_results(assigns) do
    ~H"""
    <div class="text-center mt-12 mx-auto w-full">
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
      <h3 class="mt-2 font-medium text-gray-900">No results</h3>
      <p class="mt-1 text-gray-500">No incidents matched this criteria</p>
      <div class="mt-6">
        <a href="/incidents" class="button ~urge @high">
          View All &rarr;
        </a>
      </div>
    </div>
    """
  end

  def user_stack(assigns) do
    max = Map.get(assigns, :max, 5)

    ~H"""
    <div class="flex -space-x-1 relative z-0 items-center">
      <%= for user <- @users |> Enum.take(5) do %>
        <.popover class="inline">
          <img
            class="relative z-30 inline-block h-5 w-5 rounded-full ring-2 ring-white"
            src={Accounts.get_profile_photo_path(user)}
            alt={"Profile photo for #{user.username}"}
          />
          <:display>
            <.user_card user={user} />
          </:display>
        </.popover>
      <% end %>
      <%= if length(@users) > max do %>
        <div class="bg-gray-300 text-gray-700 text-xl rounded-full mt-1 h-5 w-5 z-30 ring-2 ring-white flex items-center justify-center">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-3 w-3"
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

  def document_preview(%{file_name: file_name} = assigns) do
    ~H"""
    <div class="flex gap-2 flex-col items-center bg-neutral-100 border rounded p-2">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="currentColor"
        class="w-6 h-6 text-urge-600"
      >
        <path
          fill-rule="evenodd"
          d="M5.625 1.5H9a3.75 3.75 0 013.75 3.75v1.875c0 1.036.84 1.875 1.875 1.875H16.5a3.75 3.75 0 013.75 3.75v7.875c0 1.035-.84 1.875-1.875 1.875H5.625a1.875 1.875 0 01-1.875-1.875V3.375c0-1.036.84-1.875 1.875-1.875zm6.905 9.97a.75.75 0 00-1.06 0l-3 3a.75.75 0 101.06 1.06l1.72-1.72V18a.75.75 0 001.5 0v-4.19l1.72 1.72a.75.75 0 101.06-1.06l-3-3z"
          clip-rule="evenodd"
        />
        <path d="M14.25 5.25a5.23 5.23 0 00-1.279-3.434 9.768 9.768 0 016.963 6.963A5.23 5.23 0 0016.5 7.5h-1.875a.375.375 0 01-.375-.375V5.25z" />
      </svg>
      <p class="text-sm font-medium text-center"><%= file_name %></p>
      <p class="text-xs text-center"><%= Map.get(assigns, :description, "Document") %></p>
    </div>
    """
  end

  def media_version_display(
        %{version: version, current_user: current_user, media: media} = assigns
      ) do
    # Verify it was archived successfully
    media_to_show = version.status == :complete && !is_nil(version.mime_type)
    should_blur_js_bool = if Media.is_graphic(media), do: "true", else: "false"

    # Whether to show controls for hiding, adding media (requires that the caller be able to handle the events)
    show_controls = Map.get(assigns, :show_controls, true)

    ~H"""
    <section
      id={"version-#{version.id}"}
      class="py-4 target:outline outline-2 outline-urge-600 rounded outline-offset-2"
      x-data={"{grayscale: true, hidden: #{should_blur_js_bool}}"}
    >
      <% loc = Material.media_version_location(version, media) %>
      <% thumbnail = Material.media_version_location(version, media, :thumb) %>
      <% media_id = "version-#{version.id}-media" %>
      <div class="relative">
        <%= if media_to_show do %>
          <div id={media_id} x-bind:class="hidden ? 'invisible' : ''">
            <div x-bind:class="grayscale ? 'grayscale' : ''">
              <%= if String.starts_with?(version.mime_type, "image/") do %>
                <img src={loc} class="w-full" />
              <% else %>
                <video controls preload="none" poster={thumbnail} muted>
                  <source src={loc} class="w-full" />
                </video>
              <% end %>
            </div>
          </div>
        <% end %>
        <%= if version.status != :pending do %>
          <div
            class="w-full z-[100] h-full min-h-[50px] absolute bg-neutral-50 border rounded-lg flex items-center justify-around top-0"
            x-show="hidden"
          >
            <!-- Overlay for potentially graphic content -->
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
                  d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"
                />
              </svg>
              <h3 class="mt-2 font-medium text-gray-900 text-sm">Potentially Graphic</h3>
              <p class="mt-1 text-gray-500 text-sm">
                This media may be graphic. Please proceed with caution.
              </p>
              <button
                type="button"
                x-on:click="hidden = false"
                class="button mt-1 original py-1 px-2 text-xs"
              >
                View
              </button>
            </div>
          </div>
        <% end %>
        <%= if not media_to_show do %>
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
            <% end %>
            <%= if version.status == :error do %>
              <a
                target="_blank"
                href={version.source_url}
                rel="nofollow"
                class="text-center w-48 block"
                data-confirm="This link will open an external site in a new tab. Are you sure?"
              >
                <.url_icon url={version.source_url} class="mx-auto h-10 w-10 shadow-sm" />
                <% display =
                  if String.length(version.source_url) > 50,
                    do: String.slice(version.source_url, 0..50) <> "...",
                    else: version.source_url %>
                <h3 class="mt-2 break-all font-medium text-gray-900 text-sm"><%= display %></h3>
                <span class="button mt-1 original py-1 px-2 text-xs">
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
                </span>
              </a>
            <% end %>
          </div>
        <% end %>
      </div>
      <div class="flex gap-1 mt-1 text-sm max-w-full flex-wrap items-center justify-between">
        <span class="flex items-center gap-2 flex-wrap">
          <%= if version.status != :error do %>
            <.url_icon url={version.source_url} class="h-6" />
          <% end %>
          <span class="font-mono">
            <%= Material.get_human_readable_media_version_name(media, version) %>
          </span>
          <%= if version.upload_type == :user_provided do %>
            <span class="badge ~neutral self-start">User Upload</span>
          <% end %>
          <%= if version.status == :error and show_controls do %>
            <div
              class="text-gray-400"
              data-tooltip="Atlos could not archive this URL automatically, but you can view it directly."
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                class="w-4 h-4"
              >
                <path
                  fill-rule="evenodd"
                  d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a.75.75 0 000 1.5h.253a.25.25 0 01.244.304l-.459 2.066A1.75 1.75 0 0010.747 15H11a.75.75 0 000-1.5h-.253a.25.25 0 01-.244-.304l.459-2.066A1.75 1.75 0 009.253 9H9z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
          <% end %>
        </span>
        <%= if media_to_show or show_controls do %>
          <div class="flex gap-1 items-center">
            <div class="relative inline-block text-left" x-data="{open: false}">
              <div>
                <button
                  type="button"
                  class="flex items-center rounded-full text-gray-500 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-urge-500 focus:ring-offset-2 focus:ring-offset-gray-100"
                  aria-expanded="true"
                  aria-haspopup="true"
                  x-on:click.prevent="open = !open"
                  x-on:click.outside="open = false"
                >
                  <span class="sr-only">Open options</span>
                  <!-- Heroicon name: mini/ellipsis-vertical -->
                  <svg
                    class="h-5 w-5"
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                    aria-hidden="true"
                  >
                    <path d="M10 3a1.5 1.5 0 110 3 1.5 1.5 0 010-3zM10 8.5a1.5 1.5 0 110 3 1.5 1.5 0 010-3zM11.5 15.5a1.5 1.5 0 10-3 0 1.5 1.5 0 003 0z" />
                  </svg>
                </button>
              </div>
              <div
                class="absolute right-0 z-10 mt-2 w-48 origin-top-right rounded-md bg-white shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none overflow-visible z-[100]"
                role="menu"
                aria-orientation="vertical"
                aria-labelledby="menu-button"
                x-show="open"
                x-transition
              >
                <div class="py-1" role="none">
                  <%= if media_to_show do %>
                    <button
                      type="button"
                      rel="nofollow"
                      title="Toggle Color"
                      x-on:click="grayscale = !grayscale"
                      class="text-gray-700 px-2 py-2 text-sm flex items-center gap-2 hover:bg-gray-100 w-full"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        viewBox="0 0 24 24"
                        class="h-5 w-5 text-neutral-500"
                        fill="currentColor"
                      >
                        <path fill="none" d="M0 0h24v24H0z" /><path d="M12 2c5.522 0 10 3.978 10 8.889a5.558 5.558 0 0 1-5.556 5.555h-1.966c-.922 0-1.667.745-1.667 1.667 0 .422.167.811.422 1.1.267.3.434.689.434 1.122C13.667 21.256 12.9 22 12 22 6.478 22 2 17.522 2 12S6.478 2 12 2zM7.5 12a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3zm9 0a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3zM12 9a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z" />
                      </svg>
                      Toggle Color
                    </button>
                    <a
                      target="_blank"
                      href={version.source_url}
                      rel="nofollow"
                      title="Source"
                      role="menuitem"
                      class="text-gray-700 px-2 py-2 text-sm flex items-center gap-2 hover:bg-gray-100"
                      data-confirm="This link will open an external site in a new tab. Are you sure?"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        viewBox="0 0 24 24"
                        fill="currentColor"
                        class="w-5 h-5 text-neutral-500"
                      >
                        <path d="M11.47 1.72a.75.75 0 011.06 0l3 3a.75.75 0 01-1.06 1.06l-1.72-1.72V7.5h-1.5V4.06L9.53 5.78a.75.75 0 01-1.06-1.06l3-3zM11.25 7.5V15a.75.75 0 001.5 0V7.5h3.75a3 3 0 013 3v9a3 3 0 01-3 3h-9a3 3 0 01-3-3v-9a3 3 0 013-3h3.75z" />
                      </svg>
                      View Source
                    </a>
                    <a
                      target="_blank"
                      href={loc}
                      rel="nofollow"
                      role="menuitem"
                      title="Download"
                      class="text-gray-700 px-2 py-2 text-sm flex items-center gap-2 hover:bg-gray-100 w-full"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        viewBox="0 0 24 24"
                        fill="currentColor"
                        class="h-5 w-5 text-neutral-500"
                      >
                        <path
                          fill-rule="evenodd"
                          d="M19.5 21a3 3 0 003-3V9a3 3 0 00-3-3h-5.379a.75.75 0 01-.53-.22L11.47 3.66A2.25 2.25 0 009.879 3H4.5a3 3 0 00-3 3v12a3 3 0 003 3h15zm-6.75-10.5a.75.75 0 00-1.5 0v4.19l-1.72-1.72a.75.75 0 00-1.06 1.06l3 3a.75.75 0 001.06 0l3-3a.75.75 0 10-1.06-1.06l-1.72 1.72V10.5z"
                          clip-rule="evenodd"
                        />
                      </svg>
                      Download
                    </a>
                    <button
                      type="button"
                      rel="nofollow"
                      role="menuitem"
                      title="Copy Hash Information"
                      class="text-gray-700 px-2 py-2 text-sm flex items-center gap-2 hover:bg-gray-100 w-full"
                      onclick={
                      "window.setClipboard(JSON.stringify(" <>
                        Jason.encode!(
                          if version.hashes == %{},
                            do: %{error: "no hash information available"},
                            else: version.hashes
                        ) <>
                        ", null, 4))"
                    }
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        viewBox="0 0 24 24"
                        fill="currentColor"
                        class="w-5 h-5 text-neutral-500"
                      >
                        <path
                          fill-rule="evenodd"
                          d="M7.502 6h7.128A3.375 3.375 0 0118 9.375v9.375a3 3 0 003-3V6.108c0-1.505-1.125-2.811-2.664-2.94a48.972 48.972 0 00-.673-.05A3 3 0 0015 1.5h-1.5a3 3 0 00-2.663 1.618c-.225.015-.45.032-.673.05C8.662 3.295 7.554 4.542 7.502 6zM13.5 3A1.5 1.5 0 0012 4.5h4.5A1.5 1.5 0 0015 3h-1.5z"
                          clip-rule="evenodd"
                        />
                        <path
                          fill-rule="evenodd"
                          d="M3 9.375C3 8.339 3.84 7.5 4.875 7.5h9.75c1.036 0 1.875.84 1.875 1.875v11.25c0 1.035-.84 1.875-1.875 1.875h-9.75A1.875 1.875 0 013 20.625V9.375zm9.586 4.594a.75.75 0 00-1.172-.938l-2.476 3.096-.908-.907a.75.75 0 00-1.06 1.06l1.5 1.5a.75.75 0 001.116-.062l3-3.75z"
                          clip-rule="evenodd"
                        />
                      </svg>
                      Copy Hash Info
                    </button>
                  <% end %>
                  <%= if version.visibility == :visible and show_controls do %>
                    <button
                      type="button"
                      data-confirm="Are you sure you want to change the visibility of this media for all users on Atlos?"
                      phx-click="set_media_visibility"
                      phx-value-version={version.id}
                      phx-value-state="hidden"
                      class="text-gray-700 px-2 py-2 text-sm flex items-center gap-2 hover:bg-gray-100 w-full"
                      title="Hide"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-5 w-5 text-neutral-500"
                        viewBox="0 0 20 20"
                        fill="currentColor"
                      >
                        <path
                          fill-rule="evenodd"
                          d="M10 18a8 8 0 100-16 8 8 0 000 16zM7 9a1 1 0 000 2h6a1 1 0 100-2H7z"
                          clip-rule="evenodd"
                        />
                      </svg>
                      Hide
                    </button>
                  <% end %>
                  <%= if version.visibility == :hidden and show_controls do %>
                    <button
                      type="button"
                      data-confirm="Are you sure you want to change the visibility of this media version?"
                      phx-click="set_media_visibility"
                      phx-value-version={version.id}
                      phx-value-state="visible"
                      class="text-gray-700 px-2 py-2 text-sm flex items-center gap-2 hover:bg-gray-100 w-full"
                      title="Unhide"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-5 w-5 text-neutral-500"
                        viewBox="0 0 20 20"
                        fill="currentColor"
                      >
                        <path
                          fill-rule="evenodd"
                          d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z"
                          clip-rule="evenodd"
                        />
                      </svg>
                      Unhide
                    </button>
                  <% end %>
                  <%= if Accounts.is_privileged(current_user) and show_controls do %>
                    <button
                      type="button"
                      data-confirm="Are you sure you want to change the visibility of this media version?"
                      phx-click="set_media_visibility"
                      phx-value-version={version.id}
                      phx-value-state={
                        if version.visibility == :removed, do: "visible", else: "removed"
                      }
                      title={if version.visibility == :removed, do: "Undo Removal", else: "Remove"}
                      class="text-gray-700 px-2 py-2 text-sm flex items-center gap-2 hover:bg-gray-100 w-full"
                    >
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        class="h-5 w-5 text-neutral-500"
                        viewBox="0 0 20 20"
                        fill="currentColor"
                      >
                        <path
                          fill-rule="evenodd"
                          d="M13.477 14.89A6 6 0 015.11 6.524l8.367 8.368zm1.414-1.414L6.524 5.11a6 6 0 018.367 8.367zM18 10a8 8 0 11-16 0 8 8 0 0116 0z"
                          clip-rule="evenodd"
                        />
                      </svg>
                      <%= if version.visibility == :removed, do: "Undo Removal", else: "Remove" %>
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </section>
    """
  end

  def edit_attribute(%{attr: attr, form: f, media_slug: slug, media: media} = assigns) do
    optional = Map.get(assigns, :optional, false)

    label = attr.label <> if optional, do: " (Optional)", else: ""

    ~H"""
    <div x-data="{user_loc: null}">
      <%= case attr.type do %>
        <% :text -> %>
          <%= label(f, attr.schema_field, label) %>
          <%= textarea(f, attr.schema_field, rows: 3) %>
          <%= error_tag(f, attr.schema_field) %>
        <% :select -> %>
          <%= label(f, attr.schema_field, label) %>
          <%= error_tag(f, attr.schema_field) %>
          <div phx-update="ignore" id={"attr_select_#{slug}_#{attr.schema_field}"}>
            <%= select(
              f,
              attr.schema_field,
              if(attr.required, do: [], else: ["[Unset]": nil]) ++
                Attribute.options(attr),
              data_descriptions: Jason.encode!(attr.option_descriptions || %{}),
              data_privileged: Jason.encode!(attr.privileged_values || [])
            ) %>
          </div>
        <% :multi_select -> %>
          <%= label(f, attr.schema_field, label) %>
          <%= error_tag(f, attr.schema_field) %>
          <div phx-update="ignore" id={"attr_multi_select_#{slug}_#{attr.schema_field}"}>
            <%= multiple_select(
              f,
              attr.schema_field,
              Attribute.options(
                attr,
                if(is_nil(media), do: nil, else: Map.get(media, attr.schema_field))
              ),
              data_descriptions: Jason.encode!(attr.option_descriptions || %{}),
              data_privileged: Jason.encode!(attr.privileged_values || []),
              data_allow_user_defined_options: Attribute.allow_user_defined_options(attr)
            ) %>
          </div>
        <% :location -> %>
          <div class="space-y-4">
            <div>
              <%= label(f, :location, label <> " (latitude, longitude)") %>
              <%= text_input(f, :location,
                placeholder: "Comma-separated coordinates (lat, lon).",
                novalidate: true,
                phx_debounce: 500,
                "x-on:input": "user_loc = $event.target.value"
              ) %>
              <%= error_tag(f, :location) %>
            </div>
            <%= error_tag(f, attr.schema_field) %>
          </div>
        <% :time -> %>
          <%= label(f, attr.schema_field, label) %>
          <div class="flex items-center gap-2 ts-ignore sm:w-64 apply-a17t-fields">
            <%= time_select(f, attr.schema_field,
              hour: [prompt: "[Unset]"],
              minute: [prompt: "[Unset]"],
              class: "select",
              phx_debounce: 500
            ) %>
          </div>
          <p class="support">
            To unset this attribute, set both the hour and minute fields to [Unset].
          </p>
          <%= error_tag(f, attr.schema_field) %>
        <% :date -> %>
          <%= label(f, attr.schema_field, label) %>
          <div class="flex items-center gap-2 ts-ignore apply-a17t-fields">
            <%= date_select(f, attr.schema_field,
              year: [prompt: "[Unset]", options: DateTime.utc_now().year..1990],
              month: [prompt: "[Unset]"],
              day: [prompt: "[Unset]"],
              class: "select",
              phx_debounce: 500
            ) %>
          </div>
          <p class="support">
            To unset this attribute, set the day, month, and year fields to [Unset].
          </p>
          <%= error_tag(f, attr.schema_field) %>
      <% end %>
      <%= if attr.type == :location do %>
        <a
          class="support text-urge-700 underline mt-4"
          target="_blank"
          x-show="user_loc != null && user_loc.length > 0"
          x-bind:href="'https://maps.google.com/maps?q=' + (user_loc || '').replace(' ', '')"
        >
          Preview <span class="font-bold" x-text="user_loc"></span> on Google Maps
        </a>
      <% end %>
    </div>
    """
  end

  def popover(assigns) do
    ~H"""
    <span>
      <div class={Map.get(assigns, :class, "")} data-popover>
        <%= render_slot(@inner_block) %>
        <section role="popover" class="hidden">
          <object>
            <%= render_slot(@display) %>
          </object>
        </section>
      </div>
    </span>
    """
  end

  defp user_name_display(%{user: %Accounts.User{} = user} = assigns) do
    ~H"""
    <a
      class="font-medium text-gray-900 hover:text-urge-600 inline-flex gap-1 flex-wrap"
      href={if is_nil(user), do: "#", else: "/profile/#{user.username}"}
    >
      <%= if is_nil(user) do %>
        [System]
      <% else %>
        <%= user.username %>
        <%= if Accounts.is_admin(user) do %>
          <span class="font-normal text-xs badge ~critical self-center">Admin</span>
        <% end %>
        <%= if String.length(user.flair) > 0 do %>
          <span class="font-normal text-xs badge ~urge self-center"><%= user.flair %></span>
        <% end %>
      <% end %>
    </a>
    """
  end

  def user_card(%{user: %Accounts.User{} = user} = assigns) do
    ~H"""
    <.link navigate={"/profile/" <> user.username}>
      <div class="flex items-center gap-4 p-2">
        <div class="w-12">
          <img
            class="relative z-30 inline-block h-12 w-12 rounded-full ring-2 ring-white"
            src={Accounts.get_profile_photo_path(user)}
            alt={"Profile photo for #{user.username}"}
          />
        </div>
        <div class="flex flex-col gap-1">
          <.user_name_display user={user} />
          <p class="text-neutral-600">
            <%= if is_nil(user.bio) or String.length(user.bio |> String.trim()) == 0,
              do: "This user has not provided a bio.",
              else: user.bio %>
          </p>
        </div>
      </div>
    </.link>
    """
  end

  def user_text(%{user: %Accounts.User{} = user} = assigns) do
    ~H"""
    <.popover class="inline">
      <.user_name_display user={user} />
      <:display>
        <%= if is_nil(user) do %>
          This is an administrative user.
        <% else %>
          <.user_card user={user} />
        <% end %>
      </:display>
    </.popover>
    """
  end

  def media_text(%{media: %Media{} = media} = assigns) do
    ~H"""
    <.popover class="inline overflow-hidden" no_pad={true}>
      <span class="text-button text-gray-800 inline-block mr-2">
        <.link navigate={"/incidents/" <> media.slug}><%= media.slug %> &nearr;</.link>
      </span>
      <:display>
        <div class="-m-3 w-[350px] h-[190px] rounded">
          <.media_card_lazy media={media} />
        </div>
      </:display>
    </.popover>
    """
  end

  def floating_warning(assigns) do
    ~H"""
    <section class="fixed bottom-0 inset-x-0 pb-2 sm:pb-5 z-50">
      <div class="max-w-7xl mx-auto md:pl-36 px-2 sm:px-6 md:px-8">
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

  def floating_info(assigns) do
    ~H"""
    <section class="fixed bottom-0 inset-x-0 pb-2 sm:pb-5 z-50">
      <div class="max-w-7xl mx-auto md:pl-36 px-2 sm:px-6 md:px-8">
        <div class="p-2 rounded-lg bg-neutral-600 shadow-lg sm:p-3">
          <div class="flex items-center justify-between flex-wrap">
            <div class="w-0 flex-1 flex items-center">
              <span class="flex p-2 rounded-lg bg-neutral-800">
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
                    d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
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

  def footer_legal_language(assigns) do
    # Some of the code below might look like it's formatted strangely. And it is.
    # It's to keep the spacing right, and to prevent the autoformatter from screwing it up.
    ~H"""
    <div class="text-center text-xs mt-4">
      <p>
        Atlos is <a href="https://github.com/milesmcc/atlos" class="underline">open source</a>.
      </p>
      <p>
        By using Atlos, you agree to our <a
          href="https://github.com/milesmcc/atlos/blob/main/policy/TERMS_OF_USE.md"
          class="underline"
        >
          Terms of Use</a>&nbsp;and our <a
          href={
            System.get_env(
              "RULES_LINK",
              "https://github.com/milesmcc/atlos/blob/main/policy/RULES.md"
            )
          }
          class="underline"
        >Rules</a>.
      </p>
    </div>
    """
  end

  def footer(assigns) do
    ~H"""
    <footer class="place-self-center max-w-lg mx-auto mt-8 text-gray-500 text-xs">
      <div class="grid grid-cols-3 text-center gap-4 md:flex md:justify-between">
        <a href="https://github.com/milesmcc/atlos" class="hover:text-gray-600">Source Code</a>
        <a
          href={
            System.get_env(
              "RULES_LINK",
              "https://github.com/milesmcc/atlos/blob/main/policy/RULES.md"
            )
          }
          class="hover:text-gray-600 transition"
        >
          Rules
        </a>
        <a
          href="https://github.com/milesmcc/atlos/blob/main/policy/TERMS_OF_USE.md"
          class="hover:text-gray-600 transition"
        >
          Terms of Use
        </a>
        <a
          href="https://github.com/milesmcc/atlos/blob/main/policy/RESILIENCE.md"
          class="hover:text-gray-600 transition"
        >
          Resilience
        </a>
        <a href="https://github.com/milesmcc/atlos/discussions" class="hover:text-gray-600 transition">
          Feedback
        </a>
        <a href="mailto:contact@atlos.org" class="hover:text-gray-600 transition">Contact</a>
      </div>
    </footer>
    """
  end
end
