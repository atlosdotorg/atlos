defmodule PlatformWeb.Components do
  use Phoenix.Component
  use Phoenix.HTML
  import PlatformWeb.ErrorHelpers

  alias Phoenix.LiveView.JS
  alias Platform.Accounts
  alias Platform.Material.Attribute
  alias Platform.Material.Media
  alias Platform.Material
  alias Platform.Utils
  alias Platform.Notifications
  alias Platform.Uploads
  alias PlatformWeb.Router.Helpers, as: Routes
  alias Platform.Permissions

  def navlink(%{request_path: path, to: to} = assigns) do
    active = String.starts_with?(path, to) and !String.equivalent?(path, "/")

    classes =
      if active do
        "transition self-start bg-neutral-800 text-white group w-full p-3 rounded-md flex flex-col items-center text-xs font-medium"
      else
        "transition self-start text-neutral-100 hover:bg-neutral-800 hover:text-white group w-full p-3 rounded-md flex flex-col items-center text-xs font-medium"
      end

    assigns = assign(assigns, :classes, classes)

    ~H"""
    <%= link to: @to, class: @classes do %>
      <%= render_slot(@inner_block) %>
      <span class="mt-2"><%= @label %></span>
    <% end %>
    """
  end

  def modal(assigns) do
    assigns =
      assign_new(assigns, :id, fn -> "default" end)
      |> assign_new(:js_on_close, fn -> "" end)
      |> assign_new(:wide, fn -> false end)

    ~H"""
    <div
      class="fixed z-[10000] inset-0 overflow-y-auto"
      aria-labelledby="modal-title"
      role="dialog"
      aria-modal="true"
      phx-hook="Modal"
      data-is-modal
      id={"modal-" <> @id}
      x-data
    >
      <div
        class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0"
        @keydown.escape="window.closeModal($event)"
        phx-target={@target}
      >
        <div
          class="fixed inset-0 bg-gray-500/50 transition opacity-0"
          phx-mounted={
            JS.transition({"ease-in duration-75", "opacity-0", "opacity-100"},
              time: 75
            )
          }
          aria-hidden="true"
          x-on:click={"window.closeModal($event); " <> @js_on_close}
          phx-target={@target}
          id={"modal-overlay-" <> @id}
        >
        </div>
        <!-- This element is to trick the browser into centering the modal contents. -->
        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">
          &#8203;
        </span>

        <div
          class={"mt-24 mb-8 md:mt-0 relative inline-block opacity-0 scale-75 align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left shadow-xl transform transition-all sm:align-middle md:ml-28 sm:max-w-xl sm:w-full sm:p-6 max-w-full " <> if @wide, do: "md:max-w-3xl lg:max-w-4xl xl:max-w-5xl", else: ""}
          phx-mounted={
            JS.transition({"ease-out duration-75", "opacity-0 scale-75", "opacity-100 scale-100"},
              time: 75
            )
          }
          phx-remove={
            JS.transition({"ease-out duration-75", "opacity-100 scale-100", "opacity-0 scale-75"},
              time: 50
            )
          }
        >
          <div class="hidden sm:block absolute z-50 top-0 right-0 pt-4 pr-4">
            <button
              type="button"
              class="text-gray-400 bg-white/75 backdrop-blur rounded-full hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-urge-500 p-1"
              x-on:click={"window.closeModal($event); " <> @js_on_close}
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

        "loading" ->
          ~H"""
          <svg
            aria-hidden="true"
            class="w-5 h-5 mt-1 text-gray-200 animate-spin fill-blue-600"
            viewBox="0 0 100 101"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z"
              fill="currentColor"
            />
            <path
              d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z"
              fill="currentFill"
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

    assigns = assigns |> assign(:icon, icon)

    ~H"""
    <div
      class="max-w-sm w-full bg-white shadow-lg rounded-lg pointer-events-auto ring-1 ring-black ring-opacity-5 overflow-hidden"
      id={@id}
    >
      <div class="p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <%= @icon %>
          </div>
          <div class="ml-3 w-0 flex-1 pt-0.5">
            <%= if String.length(@title) > 0 do %>
              <div class="!text-sm font-medium text-gray-900 mb-1"><%= @title %></div>
            <% end %>
            <div class="!text-sm text-gray-500"><%= render_slot(@inner_block) %></div>
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

    assigns =
      assigns |> assign(:name, name) |> assign(:version, version) |> assign(:runtime, runtime)

    ~H"""
    <div class="md:w-28 h-20"></div>
    <div
      class="w-full md:w-28 bg-neutral-700 overflow-y-auto fixed z-50 md:h-screen self-start"
      x-data="{ open: window.innerWidth >= 768 }"
      x-transition
    >
      <div class="w-full pt-6 flex flex-col items-center md:h-full">
        <div class="flex w-full px-4 md:px-0 border-b pb-6 md:pb-0 md:border-0 border-neutral-600 justify-between md:justify-center items-center">
          <%= link to: "/", class: "flex gap-2 md:gap-0 md:flex-col items-center text-white", title: "Atlos version #{@version} (runtime: #{@runtime})" do %>
            <span class="text-xl py-px px-1 rounded-sm bg-white text-neutral-700 uppercase font-extrabold font-mono">
              Atlos
            </span>
            <%= if not is_nil(@name) do %>
              <span class="font-mono md:text-sm uppercase font-medium text-xl md:mt-1">
                <%= @name %>
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
        >
          <.navlink to="/home" label="Home" request_path={@path}>
            <Heroicons.home solid class="text-neutral-300 group-hover:text-white h-6 w-6" />
          </.navlink>

          <.navlink to="/new" label="New" request_path={@path}>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="text-neutral-300 group-hover:text-white h-6 w-6"
            >
              <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
            </svg>
          </.navlink>

          <.navlink
            to={
              if String.starts_with?(@path, "/incidents"),
                do: "/incidents",
                else:
                  Routes.live_path(
                    @endpoint,
                    PlatformWeb.MediaLive.Index,
                    Accounts.active_incidents_params(@current_user)
                  )
            }
            label="Incidents"
            request_path={@path}
          >
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

          <.navlink to="/projects" label="Projects" request_path={@path}>
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

    assigns = assign(assigns, :active_index, active_index)

    ~H"""
    <nav aria-label="Progress">
      <ol
        role="list"
        class="border border-gray-300 rounded-md divide-y divide-gray-300 md:flex md:divide-y-0 bg-white"
      >
        <%= for {item, index} <- Enum.with_index(@options) do %>
          <li class="relative md:flex-1 md:flex">
            <%= if index < @active_index do %>
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

            <%= if index == @active_index do %>
              <!-- Current Step -->
              <div class="px-6 py-4 flex items-center text-sm font-medium" aria-current="step">
                <span class="flex-shrink-0 w-10 h-10 flex items-center justify-center border-2 border-urge-600 rounded-full">
                  <span class="text-urge-600"><%= index + 1 %></span>
                </span>
                <span class="ml-4 text-sm font-medium text-urge-600"><%= item %></span>
              </div>
            <% end %>

            <%= if index > @active_index do %>
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

            <%= if index != length(@options) - 1 do %>
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

  def media_line_preview(%{media: %Media{}} = assigns) do
    ~H"""
    <article class="flex flex-wrap md:flex-nowrap w-full gap-1 justify-between text-sm md:items-center max-w-full">
      <div class="flex-shrink-0">
        <.media_text class="text-neutral-500" media={@media} />
      </div>
      <.link
        href={"/incidents/#{@media.slug}"}
        class="md:hidden flex items-center flex-shrink-0 text-xs items-center flex-shrink-1 gap-1 justify-right"
      >
        <.media_badges media={@media} only_status={true} />
      </.link>
      <.link
        href={"/incidents/#{@media.slug}"}
        class="font-medium flex-grow-1 hover:text-urge-600 transition flex items-center max-w-full gap-2 grow truncate min-w-0"
      >
        <span class="truncate"><%= @media.attr_description %></span>
      </.link>
      <.link
        href={"/incidents/#{@media.slug}"}
        class="hidden md:block flex items-center flex-shrink-0 text-xs items-center flex-shrink-1 gap-1 justify-right"
      >
        <.media_badges media={@media} only_status={true} />
      </.link>
    </article>
    """
  end

  attr(:project, Platform.Projects.Project, required: false)

  def project_text(assigns) do
    ~H"""
    <%= if !is_nil(@project) do %>
      <.link
        href={"/projects/#{@project.id}"}
        class="font-medium inline-flex gap-px text-button text-neutral-800 items-center"
      >
        <%= @project.name %>
        <span style={"color: #{@project.color}"}>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            class="w-4 h-4"
          >
            <circle cx="10" cy="10" r="5" />
          </svg>
        </span>
      </.link>
    <% else %>
      <div class="font-medium inline-flex gap-px text-button text-neutral-800">
        [Deleted Project]
      </div>
    <% end %>
    """
  end

  def attribute_icon(assigns) do
    assigns =
      assigns
      |> assign_new(:class, fn -> Map.get(assigns, :class, "h-6 w-6") end)
      |> assign_new(:type, fn -> :outline end)

    # Note that this function assumes that @value is the value of each individual value in multi-selects, and not the value of the overall multiselect

    ~H"""
    <%= case @name do %>
      <% :status -> %>
        <%= case @value do %>
          <% "Completed" -> %>
            <Heroicons.check {%{@type => true}} class={@class} />
          <% "Ready for Review" -> %>
            <Heroicons.shield_check {%{@type => true}} class={@class} />
          <% "In Progress" -> %>
            <Heroicons.clock {%{@type => true}} class={@class} />
          <% "Unclaimed" -> %>
            <Heroicons.flag {%{@type => true}} class={@class} />
          <% "Cancelled" -> %>
            <Heroicons.x_mark {%{@type => true}} class={@class} />
          <% "Help Needed" -> %>
            <Heroicons.chat_bubble_oval_left_ellipsis {%{@type => true}} class={@class} />
          <% _ -> %>
            <Heroicons.flag {%{@type => true}} class={@class} />
        <% end %>
      <% :sensitive -> %>
        <%= case @value do %>
          <% "Not Sensitive" -> %>
          <% _ -> %>
            <Heroicons.shield_exclamation {%{@type => true}} class={@class} />
        <% end %>
      <% _ -> %>
    <% end %>
    """
  end

  def update_entry(assigns) do
    profile_ring_classes =
      if Map.get(assigns, :profile_ring, true) do
        "ring-8 ring-white"
      else
        ""
      end

    update = Map.get(assigns, :update)

    assigns =
      assign(assigns, :profile_ring_classes, profile_ring_classes)
      |> assign_new(:ignore_permissions, fn -> false end)

    if is_list(update) do
      [head | _] = update

      attributes =
        update
        |> Enum.map(&Attribute.get_attribute(&1.modified_attribute, project: &1.media.project))
        |> Enum.sort()
        |> Enum.uniq()

      n_attributes = length(attributes)

      assigns =
        assign(assigns, :n_attributes, n_attributes)
        |> assign(:attributes, attributes)
        |> assign(:head, head)
        |> assign(:can_user_change_visibility, false)

      ~H"""
      <li x-data="{expanded: false}" id={"collapsed-update-#{@head.id}"}>
        <div
          class={"relative group word-breaks cursor-pointer " <> (if @show_line, do: "pb-8", else: "")}
          x-on:click="expanded = !expanded"
          class="group"
        >
          <%= if @show_line do %>
            <span class="absolute top-5 left-5 -ml-px h-full w-0.5 bg-gray-200" aria-hidden="true">
            </span>
          <% end %>
          <div class="relative flex items-start space-x-2">
            <%= if @left_indicator == :profile do %>
              <div class="relative">
                <a href={"/profile/#{@head.user.username}"}>
                  <img
                    class={"h-10 w-10 rounded-full bg-gray-400 flex items-center justify-center shadow " <> @profile_ring_classes}
                    src={Accounts.get_profile_photo_path(@head.user)}
                    alt={"Profile photo for #{@head.user.username}"}
                    loading="lazy"
                  />
                </a>
              </div>
            <% end %>
            <div class="min-w-0 flex-1 flex flex-col flex-grow group-hover:bg-gray-100 focus-within:bg-gray-100 rounded px-1 py-2 transition-all mt-1">
              <div class="flex flex-wrap items-center">
                <div class="text-sm text-gray-600 flex-grow">
                  <%= if @show_media do %>
                    <.media_text media={@head.media} />
                  <% end %>
                  <.user_text user={@head.user} />
                  <%= case @head.type do %>
                    <% :update_attribute -> %>
                      made <%= length(@update) %> updates to <% changed_attrs =
                        @attributes |> Enum.filter(&(!is_nil(&1))) |> Enum.with_index() %>
                      <%= for {attr, idx} <- changed_attrs do %>
                        <span class="font-medium text-gray-800">
                          <%= attr.label <> connector_language(idx, @n_attributes) %>
                        </span>
                      <% end %>
                      <%= if Enum.empty?(changed_attrs) do %>
                        <span class="font-medium text-gray-800">
                          attributes
                        </span>
                      <% end %>
                    <% :upload_version -> %>
                      added
                      <span class="font-medium text-gray-800">
                        <%= length(@update) %> pieces of media
                      </span>
                  <% end %>
                  <.rel_time time={@head.inserted_at} />
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
          <%= for sub_update <- @update |> Enum.reverse() do %>
            <.update_entry
              update={sub_update}
              show_line={true}
              show_media={false}
              target={@target}
              socket={@socket}
              left_indicator={:dot}
              current_user={@current_user}
              ignore_permissions={@ignore_permissions}
            />
          <% end %>
        </ul>
      </li>
      """
    else
      assigns =
        assigns
        |> assign_new(
          :can_user_change_visibility,
          fn ->
            Permissions.can_user_change_update_visibility?(assigns.current_user, assigns.update)
          end
        )

      ~H"""
      <% can_user_view = Permissions.can_view_update?(@current_user, @update) %>
      <li class={"transition-all " <> (if @update.hidden and can_user_view, do: "opacity-50", else: "")}>
        <div class={"relative group word-breaks " <> (if @show_line, do: "pb-8", else: "")}>
          <%= if @show_line do %>
            <span class="absolute top-5 left-5 -ml-px h-full w-0.5 bg-gray-200" aria-hidden="true">
            </span>
          <% end %>
          <div class="relative flex items-start space-x-2">
            <%= if can_user_view or @ignore_permissions do %>
              <%= case @left_indicator do %>
                <% :profile -> %>
                  <div class="relative">
                    <a href={"/profile/#{@update.user.username}"}>
                      <img
                        class={"h-10 w-10 rounded-full bg-gray-400 flex items-center justify-center " <> @profile_ring_classes}
                        src={Accounts.get_profile_photo_path(@update.user)}
                        alt={"Profile photo for #{@update.user.username}"}
                        loading="lazy"
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
                    <%= if @show_media do %>
                      <.media_text media={@update.media} />
                    <% end %>
                    <.user_text user={@update.user} />
                    <%= case @update.type do %>
                      <% :update_attribute -> %>
                        <% attr =
                          Attribute.get_attribute(@update.modified_attribute,
                            project: @update.media.project
                          ) %> updated
                        <%= if not is_nil(attr) do %>
                          <%= live_patch class: "text-button text-gray-800 inline-block", to: Routes.media_show_path(@socket, :history, @update.media.slug, attr.name) do %>
                            <%= attr.label %> &nearr;
                          <% end %>
                        <% else %>
                          a deleted or unknown attribute
                        <% end %>
                      <% :create -> %>
                        added this incident
                      <% :delete -> %>
                        deleted this incident
                      <% :undelete -> %>
                        restored this incident
                      <% :add_project -> %>
                        moved this incident into <.project_text project={@update.new_project} />
                      <% :remove_project -> %>
                        removed this incident from <.project_text project={@update.old_project} />
                      <% :change_project -> %>
                        moved this incident from <.project_text project={@update.old_project} /> into
                        <.project_text project={@update.new_project} />
                      <% :upload_version -> %>
                        uploaded
                        <.link
                          patch={
                            Routes.media_show_path(
                              @socket,
                              :media_version_detail,
                              @update.media.slug,
                              @update.media_version.scoped_id
                            )
                          }
                          class="text-button text-gray-800"
                        >
                          <span>
                            <%= Material.get_human_readable_media_version_name(
                              @update.media,
                              @update.media_version
                            ) %>
                          </span>
                          &nearr;
                        </.link>
                      <% :comment -> %>
                        commented
                    <% end %>
                    <.rel_time time={@update.inserted_at} />
                    <%= if @update.hidden do %>
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
                    <%= if @can_user_change_visibility do %>
                      <button
                        type="button"
                        phx-target={@target}
                        phx-click="change_visibility"
                        phx-value-update={@update.id}
                        class="opacity-0 group-hover:opacity-100 text-critical-700 transition text-xs ml-2"
                        data-confirm="Are you sure you want to change the visibility of this update?"
                      >
                        <%= if @update.hidden, do: "Show", else: "Hide" %>
                      </button>
                    <% end %>
                  </div>
                </div>

                <% has_attr_change_to_show =
                  @update.type == :update_attribute and
                    not is_nil(
                      Attribute.get_attribute(@update.modified_attribute, project: @update.media.project)
                    ) %>
                <%= if has_attr_change_to_show || @update.explanation do %>
                  <div class="mt-1 text-sm text-gray-700 border border-gray-300 rounded-lg shadow-sm overflow-hidden flex flex-col divide-y">
                    <!-- Update detail section -->
                    <%= if has_attr_change_to_show do %>
                      <div class="bg-gray-50 p-2 flex">
                        <div class="flex-grow">
                          <.attr_diff
                            name={@update.modified_attribute}
                            old={Jason.decode!(@update.old_value)}
                            new={Jason.decode!(@update.new_value)}
                            project={@update.media.project}
                          />
                        </div>
                      </div>
                    <% end %>
                    <!-- Text comment section -->
                    <%= if @update.explanation do %>
                      <article class="prose text-sm p-2 w-full max-w-full bg-white">
                        <%= raw(@update.explanation |> Platform.Utils.render_markdown()) %>
                      </article>
                    <% end %>

                    <%= if not Enum.empty?(@update.attachments) do %>
                      <div class="p-2 grid grid-cols-2 md:grid-cols-3 gap-2">
                        <%= for {attachment, idx} <- @update.attachments |> Enum.with_index() do %>
                          <% url =
                            Uploads.UpdateAttachment.url({attachment, @update.media}, :original,
                              signed: true,
                              expires_in: 60 * 60 * 6
                            ) %>
                          <div class="rounded overflow-hidden max-h-64 cursor highlight-block">
                            <%= cond do %>
                              <% String.ends_with?(attachment, ".jpg") || String.ends_with?(attachment, ".jpeg") || String.ends_with?(attachment, ".png") -> %>
                                <a href={url} target="_blank">
                                  <img src={url} loading="lazy" />
                                </a>
                              <% String.ends_with?(attachment, ".mp4") -> %>
                                <video controls preload="auto" muted>
                                  <source src={url} />
                                </video>
                              <% true -> %>
                                <a href={url} target="_blank">
                                  <.document_preview
                                    file_name={"Attachment #" <> to_string(idx + 1)}
                                    description="PDF Document"
                                  />
                                </a>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="text-sm bg-white flex items-center border-2 border-dashed border-neutral-300 text-neutral-600 p-2 rounded">
                <p>
                  <span class="font-medium text-gray-800">
                    You do not have permission to see this update.
                  </span>
                  The incident may have been removed, you may have been removed from the project, or the update may have been hidden.
                </p>
              </div>
            <% end %>
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

    assigns =
      assign(assigns, :full_display_time, full_display_time)
      |> assign(:ago, ago)
      |> assign(:months, months)

    if ago > 7 * 24 * 60 * 60 do
      ~H"""
      <span data-tooltip={@full_display_time}>
        <%= @months[@time.month] %> <%= @time.day %> <%= @time.year %>
      </span>
      """
    else
      ~H"""
      <span data-tooltip={@full_display_time}><%= @ago |> time_ago_in_words() %></span>
      """
    end
  end

  def location(assigns) do
    ~H"""
    <%= @lat %>, <%= @lon %> &nearr;
    """
  end

  def attr_display_block(assigns) do
    assigns = assign_new(assigns, :immutable, fn -> false end)

    ~H"""
    <dl class="divide-y divide-dashed divide-gray-200 -mt-5 -mb-3 overflow-hidden">
      <%= for attr <- @set_attrs do %>
        <.attr_display_row
          attr={attr}
          updates={@updates}
          media={@media}
          socket={@socket}
          current_user={@current_user}
          immutable={@immutable}
        />
      <% end %>
      <%= if length(@unset_attrs) > 0 do %>
        <div class="py-2 sm:grid sm:grid-cols-3 sm:gap-4 -mb-2">
          <dt class="text-sm font-medium text-gray-500 mt-1">Add Attributes</dt>
          <dd class="mt-1 flex flex-wrap gap-2 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
            <%= for attr <- @unset_attrs do %>
              <%= live_patch("+ #{attr.label}",
                class: "button original",
                to: Routes.media_show_path(@socket, :edit, @media.slug, attr.name),
                replace: true
              ) %>
            <% end %>
          </dd>
        </div>
      <% end %>
    </dl>
    """
  end

  def url_icon(%{url: url} = assigns) do
    parsed = URI.parse(url || "https://example.com")
    loc = "https://s2.googleusercontent.com/s2/favicons?domain=#{parsed.host}&sz=256"

    assigns = assign(assigns, :loc, loc)

    ~H"""
    <img src={@loc} loading="lazy" class={"rounded " <> @class} />
    """
  end

  def attr_display_compact(assigns) do
    attr = Map.get(assigns, :attr)

    assigns =
      assign(assigns, :children, Attribute.get_children(attr.name))
      |> assign_new(:truncate, fn -> true end)
      |> assign(:attr_value, Material.get_attribute_value(assigns.media, attr))

    ~H"""
    <div class="inline">
      <%= if not is_nil(@attr_value) and @attr_value != [] and @attr_value != "" do %>
        <div class="inline-flex flex-wrap text-xs">
          <div class="break-word max-w-full text-ellipsis">
            <.attr_entry
              color={true}
              compact={@truncate}
              name={@attr.name}
              project={@media.project}
              value={@attr_value}
            />
            <%= for child <- @children do %>
              <%= if not is_nil(Map.get(@media, child.schema_field)) do %>
                <.attr_entry
                  color={true}
                  compact={@truncate}
                  name={child.name}
                  value={Material.get_attribute_value(@media, child)}
                  project={@media.project}
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

  def attr_filter(assigns) do
    assigns =
      assign(
        assigns,
        :is_active,
        Ecto.Changeset.get_change(assigns.form.source, assigns.attr.schema_field) != nil or
          (assigns.attr.type == :date and
             (Ecto.Changeset.get_change(assigns.form.source, :attr_date_min) != nil or
                Ecto.Changeset.get_change(assigns.form.source, :attr_date_max) != nil))
      )

    ~H"""
    <article
      class="relative inline-block text-left overflow-visible"
      x-data="{open: false}"
      x-on:click.away="open = false"
      id={@id}
    >
      <div>
        <button
          type="button"
          class={"inline-flex border shadow-sm rounded-lg py-1 px-2 w-full justify-center gap-x-1 text-sm text-gray-900 " <>
            if @is_active do
              "text-white bg-urge-500 border-urge-500"
            else
              "bg-white"
            end}
          aria-haspopup="true"
          x-on:click="open = !open"
        >
          <%= @attr.label %>
          <svg
            class="-mr-1 h-5 w-5 opacity-75"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
              clip-rule="evenodd"
            />
          </svg>
        </button>
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
            Filter <%= @attr.label %> to...
          </p>
          <div>
            <%= case @attr.type do %>
              <% x when x == :multi_select or x == :select -> %>
                <div phx-update="ignore" id={"attr_select_#{@attr.name}"} class="phx-form">
                  <%= multiple_select(
                    @form,
                    @attr.schema_field,
                    Attribute.options(@attr) ++ if(not @attr.required, do: ["[Unset]"], else: []),
                    id: "attr_select_#{@attr.name}_input",
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
                      "phx-debounce": "500"
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
                      class: "input-base shrink"
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
                      id: "search-form-date-min",
                      class: "input-base inline-flex items-center",
                      phx_debounce: 2000
                    ) %>
                    <span class="text-sm text-gray-600">until</span>
                    <%= date_input(
                      @form,
                      :attr_date_max,
                      id: "search-form-date-max",
                      class: "input-base inline-flex items-center",
                      phx_debounce: 2000
                    ) %>
                  </div>
                  <p class="support text-gray-600 mt-1">
                    For an open ended range, leave the field blank.
                  </p>
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

  def attr_display_row(assigns) do
    attr = Map.get(assigns, :attr)

    children = Attribute.get_children(attr.name)

    assigns =
      assign(assigns, :children, children)
      |> assign_new(:truncate, fn -> false end)
      |> assign_new(:immutable, fn -> false end)

    ~H"""
    <div class="py-2 sm:grid sm:grid-cols-3 sm:gap-2">
      <dt class="text-sm font-medium text-gray-500 mt-1 flex justify-between items-center flex-wrap">
        <span class="flex items-center gap-1">
          <%= @attr.label %>
          <%= if Platform.Material.Attribute.requires_privileges_to_edit(@attr) do %>
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
            to: Routes.media_show_path(@socket, :history, @media.slug, @attr.name)
          ) do %>
          <.user_stack users={
            @updates
            |> Enum.filter(&(&1.modified_attribute == to_string(@attr.name) || &1.type == :create))
            |> Enum.filter(&(!&1.hidden))
            |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
            |> Enum.map(& &1.user)
            |> Enum.take(1)
          } />
        <% end %>
      </dt>
      <dd class="mt-1 flex items-center text-sm text-gray-900 sm:mt-0 sm:col-span-2">
        <span class="flex-grow gap-1 flex flex-wrap">
          <%= if not is_nil(Material.get_attribute_value(@media, @attr)) do %>
            <.attr_entry
              name={@attr.name}
              color={false}
              value={Material.get_attribute_value(@media, @attr)}
              project={@media.project}
            />
            <%= for child <- @children do %>
              <%= if not is_nil(Map.get(@media, child.schema_field)) do %>
                <.attr_entry
                  name={child.name}
                  color={false}
                  value={Map.get(@media, child.schema_field)}
                  label={child.label}
                  project={@media.project}
                />
              <% end %>
            <% end %>
          <% end %>
        </span>
        <span class="ml-4 flex-shrink-0">
          <%= if Permissions.can_edit_media?(@current_user, @media, @attr) and not @immutable do %>
            <%= live_patch("Update",
              class: "text-button mt-1 inline-block",
              to: Routes.media_show_path(@socket, :edit, @media.slug, @attr.name),
              replace: true
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

  def attr_label(assigns) do
    ~H"""
    <%= if String.length(@label) > 0 do %>
      <span class="opacity-[70%]"><%= @label %>:</span>
    <% end %>
    """
  end

  def attr_entry(%{name: name, value: value, project: project} = assigns) do
    attr = Attribute.get_attribute(name, project: project)

    tone =
      if Map.get(assigns, :color, false), do: Attribute.attr_color(name, value), else: "~neutral"

    assigns =
      assign(assigns, :attr, attr)
      |> assign_new(:label, fn -> "" end)
      |> assign_new(:compact, fn -> false end)
      |> assign_new(:tone, fn -> tone end)

    ~H"""
    <span class={"inline-flex gap-1 max-w-full " <> (if @compact, do: "", else: "flex-wrap")}>
      <%= case @attr.type do %>
        <% :text -> %>
          <%= if @compact do %>
            <div class="inline-block prose prose-sm my-px word-breaks">
              <.attr_label label={@label} />
              <%= raw(
                @value
                |> String.replace("\n", "")
                |> Utils.truncate(80)
                |> Utils.render_markdown()
              ) %>
            </div>
          <% else %>
            <div class="inline-block prose prose-sm my-px word-breaks">
              <.attr_label label={@label} />
              <%= raw(
                @value
                |> Utils.render_markdown()
              ) %>
            </div>
          <% end %>
        <% :select -> %>
          <div class="inline-block">
            <div class={"chip #{@tone} flex items-center gap-1 inline-block self-start break-all xl:break-normal"}>
              <.attribute_icon
                name={@name}
                type={:solid}
                value={@value}
                class="h-4 w-4 shrink-0 opacity-50"
              />
              <.attr_label label={@label} />
              <span><%= @value %></span>
            </div>
          </div>
        <% :multi_select -> %>
          <.attr_label label={@label} />
          <%= for item <- (if @compact, do: @value |> Enum.take(1), else: @value) do %>
            <div class={"chip #{@tone} flex items-center gap-1 inline-block self-start break-all xl:break-normal"}>
              <.attribute_icon
                name={@name}
                type={:solid}
                value={item}
                class="h-4 w-4 shrink-0 opacity-50"
              />
              <span><%= item %></span>
            </div>
            <%= if @compact and length(@value) > 1 do %>
              <div class="text-xs mt-1 text-neutral-500">
                + <%= length(@value) - 1 %>
              </div>
            <% end %>
          <% end %>
        <% :location -> %>
          <div class="inline-block">
            <% {lon, lat} = @value.coordinates %>
            <a
              class={"chip #{@tone} inline-block flex gap-1 items-center self-start break-all xl:break-normal"}
              target="_blank"
              href={"https://maps.google.com/maps?q=#{lat},#{lon}"}
            >
              <.attribute_icon
                name={@name}
                type={:solid}
                value={@value}
                class="h-4 w-4 shrink-0 opacity-50"
              />
              <.attr_label label={@label} />
              <.location lat={lat} lon={lon} />
            </a>
          </div>
        <% :time -> %>
          <div class="inline-block">
            <div class={"chip #{@tone} flex items-center gap-1 inline-block self-start break-all xl:break-normal"}>
              <.attribute_icon
                name={@name}
                type={:solid}
                value={@value}
                class="h-4 w-4 shrink-0 opacity-50"
              />
              <.attr_label label={@label} />
              <%= @value %>
            </div>
          </div>
        <% :date -> %>
          <div class="inline-block">
            <div class={"chip #{@tone} flex items-center gap-1 inline-block self-start break-all xl:break-normal"}>
              <.attribute_icon
                name={@name}
                type={:solid}
                value={@value}
                class="h-4 w-4 shrink-0 opacity-50"
              />
              <.attr_label label={@label} />
              <%= Platform.Utils.format_date(@value) %>
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

  def attr_explanation(%{name: name, project: project} = assigns) do
    assigns = assign(assigns, :attr, Attribute.get_attribute(name, project: project))

    ~H"""
    <span class="inline-flex flex-wrap gap-1">
      <span class="font-medium">
        <%= if @attr.schema_field == :project_attributes,
          do: String.downcase(@attr.label),
          else: @attr.name |> to_string() %>
      </span>
      &mdash;
      <%= case @attr.type do %>
        <% :text -> %>
          freeform text
        <% :select -> %>
          one of
          <%= for item <- Attribute.options(@attr) do %>
            <div class="badge ~urge inline-block"><%= item %></div>
          <% end %>
        <% :multi_select -> %>
          a combination of
          <%= for item <- Attribute.options(@attr) do %>
            <div class="badge ~urge inline-block"><%= item %></div>
          <% end %>
          (comma separated)
          <%= if Attribute.allow_user_defined_options(@attr) do %>
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
    </span>
    """
  end

  def text_diff(%{old: old, new: new} = assigns) do
    old_words = String.split(old || "") |> Enum.map(&String.trim(&1))
    new_words = String.split(new || "") |> Enum.map(&String.trim(&1))
    diff = List.myers_difference(old_words, new_words)

    assigns = assign(assigns, :diff, diff)

    ~H"""
    <span class="text-sm">
      <.attr_label label={Map.get(assigns, :label, "")} />
      <%= for {action, elem} <- @diff do %>
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

    assigns = assign(assigns, :diff, diff)

    ~H"""
    <span class="flex flex-wrap gap-1">
      <%= for {action, elem} <- @diff do %>
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

  def location_diff(%{old: _, new: _} = assigns) do
    ~H"""
    <span>
      <%= if @old != @new do %>
        <%= case @old do %>
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
        <%= case @new do %>
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
        <%= case @new do %>
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

  def attr_diff(%{name: name, old: old, new: new, project: project} = assigns) do
    attr = Attribute.get_attribute(name, project: project)

    if not is_nil(attr) do
      assigns =
        assigns
        |> assign(:attr, attr)
        |> assign(:label, Map.get(assigns, :label, ""))
        |> assign(:children, Attribute.get_children(name))
        |> assign(
          :old_val,
          # It's possible to encode changes to multiple schema fields in one update, but some legacy/existing updates
          # have their values encoded in the old format, so we perform a render-time conversion here.
          if(Material.is_combined_update_value(old),
            do: old |> Map.get(Platform.Updates.key_for_attribute(attr)),
            else: old
          )
        )
        |> assign(
          :new_val,
          if(Material.is_combined_update_value(new),
            do: new |> Map.get(Platform.Updates.key_for_attribute(attr)),
            else: new
          )
        )

      ~H"""
      <div class="inline-block">
        <span>
          <%= case @attr.type do %>
            <% :text -> %>
              <.text_diff old={@old_val} new={@new_val} label={@label} />
            <% :select -> %>
              <.list_diff old={[@old_val]} new={[@new_val]} label={@label} />
            <% :multi_select -> %>
              <.list_diff
                old={if is_list(@old_val), do: @old_val, else: [@old_val]}
                new={if is_list(@new_val), do: @new_val, else: [@new_val]}
                label={@label}
              />
            <% :location -> %>
              <.location_diff old={@old_val} new={@new_val} label={@label} />
            <% :time -> %>
              <.list_diff old={[@old_val]} new={[@new_val]} label={@label} />
            <% :date -> %>
              <.list_diff
                old={[Platform.Utils.format_date(@old_val)]}
                new={[Platform.Utils.format_date(@new_val)]}
                label={@label}
              />
          <% end %>
        </span>
        <%= if Material.is_combined_update_value(@old) and Material.is_combined_update_value(@new) do %>
          <%= for child <- @children do %>
            <.attr_diff name={child.name} old={@old} new={@new} label={child.label} project={@project} />
          <% end %>
        <% end %>
      </div>
      """
    else
      ~H"""
      <div class="inline-block">
        <span class="italic">
          Change is unavailable
        </span>
      </div>
      """
    end
  end

  def deconfliction_warning(assigns) do
    ~H"""
    <div class="p-4 mt-4 rounded bg-gray-100 transition-all">
      <p class="text-sm">
        Note that media at this URL has already been uploaded. While you can still upload the media, take care to ensure it is not a duplicate.
      </p>
      <div class="grid grid-cols-1 gap-4 mt-4">
        <%= for dupe <- @duplicates |> Enum.filter(& Permissions.can_view_media?(@current_user, &1)) do %>
          <div data-confirm="Open the incident in a new tab? Your current upload won't be affected.">
            <.media_card media={dupe} current_user={@current_user} target="_blank" />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Like deconfliction_warning, except used when we have multiple URLs and potential media.
  """
  def multi_deconfliction_warning(%{url_media_pairs: pairs, current_user: _} = assigns) do
    assigns =
      assigns
      |> assign(
        :has_dupes,
        Enum.any?(pairs, fn {_url, media} ->
          not Enum.empty?(
            media
            |> Enum.filter(&Permissions.can_view_media?(assigns.current_user, &1))
          )
        end)
      )

    ~H"""
    <div>
      <%= if @has_dupes do %>
        <div class="rounded-md bg-yellow-50 px-4 py-3 border-yellow-300 border">
          <div class="grid grid-cols-1 gap-8">
            <%= for {url, dupes} <- @url_media_pairs do %>
              <% media = Enum.filter(dupes, &Permissions.can_view_media?(@current_user, &1)) %>
              <%= if not Enum.empty?(media) do %>
                <div>
                  <div class="text-yellow-800 text-sm">
                    <.url_icon url={url} class="h-4 w-4 inline mb-px" />
                    <a href={url} target="_blank" class="font-medium"><%= url %></a>
                    has already been added to Atlos. While you can still add it, take care to ensure it is not a duplicate.
                  </div>
                  <div class="grid grid-cols-1 gap-4 mt-2">
                    <%= for dupe <- media do %>
                      <div data-confirm="Open the incident in a new tab? Your current tab won't be affected.">
                        <.media_card media={dupe} current_user={@current_user} target="_blank" />
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      <% else %>
        <div class="rounded-md bg-green-50 p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <!-- Heroicon name: mini/check-circle -->
              <svg
                class="h-5 w-5 text-green-400"
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 20 20"
                fill="currentColor"
                aria-hidden="true"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <div class="ml-3">
              <h3 class="text-sm font-medium text-green-800">No duplicates detected</h3>
              <div class="mt-2 text-sm text-green-700">
                <p>
                  These URLs have not been previously uploaded to your projects on Atlos.
                </p>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def loading_spinner(assigns) do
    ~H"""
    <div class="flex items-center">
      <div role="status">
        <svg
          class="inline mr-2 w-4 h-4 text-neutral-200 animate-spin fill-neutral-700"
          viewBox="0 0 100 101"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z"
            fill="currentColor"
          />
          <path
            d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z"
            fill="currentFill"
          />
        </svg>
      </div>
      Loading more...
    </div>
    """
  end

  def media_table_row(%{media: _, current_user: _, attributes: _, source_cols: _} = assigns) do
    assigns =
      assigns
      |> Map.put(
        :versions,
        assigns.media.versions
        |> Enum.filter(&(&1.visibility == :visible))
      )

    ~H"""
    <% is_subscribed = @media.has_subscription %>
    <% has_unread_notification = @media.has_unread_notification %>
    <% is_sensitive = Material.Media.is_sensitive(@media) %>
    <% background_color =
      case @media.attr_sensitive do
        x when x == ["Not Sensitive"] or x == [] -> "bg-white group-hover:bg-neutral-50 hover:bg-neutral-50"
        ["Personal Information Visible"] -> "bg-orange-50"
        _ -> "bg-red-50"
      end %>
    <tr
      class={"search-highlighting group transition-all " <> background_color}
      id={@id}
      x-data={"{selected: #{@is_selected}}"}
      x-bind:class={"{'!bg-urge-50': (selected || #{@is_selected})}"}
    >
      <td
        id={"table-row-" <> @media.slug <> "-slug"}
        class={"md:sticky left-0 z-[100] pl-4 pr-1 border-r whitespace-nowrap border-b border-gray-200 h-10 transition-all " <> background_color}
        x-bind:class={"{'!bg-urge-50': (selected || #{@is_selected})}"}
      >
        <div class="flex items-center gap-1">
          <div
            class="flex-shrink-0 w-5 mr-2 group-hover:block"
            x-bind:class={"{'hidden': !(selected || #{@is_selected})}"}
            data-tooltip="Select this incident"
            x-cloak
          >
            <input
              phx-click="select"
              phx-value-slug={@media.slug}
              x-on:change="selected = $event.target.checked"
              checked={@is_selected}
              type="checkbox"
              class="h-4 w-4 mb-1 rounded border-gray-300 text-urge-600 focus:ring-urge-600"
            />
          </div>
          <div
            class="flex-shrink-0 w-5 mr-2 group-hover:hidden"
            x-bind:class={"{'hidden': (selected || #{@is_selected})}"}
            data-tooltip={"Last modified by #{List.last(@media.updates).user.username}"}
          >
            <.user_stack
              users={@media.updates |> Enum.take(1) |> Enum.map(& &1.user)}
              dynamic={false}
              ring_class="ring-transparent"
            />
          </div>
          <.link
            href={"/incidents/#{@media.slug}"}
            class="text-button text-sm flex items-center gap-1 mr-px font-mono"
          >
            <span style={"color: #{if @media.project, do: @media.project.color, else: "unset"}"}>
              <%= Media.slug_to_display(@media) %>
            </span>
            <%= if is_sensitive do %>
              <span data-tooltip={Enum.join(@media.attr_sensitive, ", ")} class="text-critical-400">
                <Heroicons.shield_exclamation mini class="h-4 w-4" />
              </span>
            <% end %>
            <%= if is_subscribed do %>
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
            <%= if has_unread_notification do %>
              <span data-tooltip="Unread notification">
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
          </.link>
        </div>
      </td>
      <%= for attr <- @attributes do %>
        <td
          class="border-b cursor-pointer p-0"
          phx-click={
            if Permissions.can_edit_media?(@current_user, @media, attr),
              do: "edit_attribute",
              else: nil
          }
          phx-value-attribute={attr.name}
          phx-value-media-id={@media.id}
          id={"table-row-" <> @media.slug <> "-" <> to_string(attr.name)}
        >
          <div class="text-sm text-gray-900 px-4 overflow-hidden h-6 max-w-[36rem] truncate">
            <.attr_display_compact
              color={true}
              truncate={true}
              attr={attr}
              media={@media}
              current_user={@current_user}
            />
          </div>
        </td>
      <% end %>
      <%= for idx <- 0..@source_cols do %>
        <td
          class="border-b cursor-pointer p-0"
          id={"table-row-" <> @media.slug <> "-source-" <> to_string(idx)}
        >
          <% version = Enum.at(@versions, idx) %>
          <%= cond do %>
            <% length(@versions) > @source_cols + 1 && idx == @source_cols -> %>
              <span class="text-neutral-400 px-4 text-sm whitespace-nowrap">
                <%= length(@versions) - @source_cols %> more source(s) available on the incident page
              </span>
            <% not is_nil(version) -> %>
              <div class="text-sm flex items-center text-gray-900 px-4 whitespace-nowrap text-ellipsis overflow-hidden h-6 w-[12rem]">
                <a
                  href={version.source_url}
                  target="_blank"
                  rel="nofollow"
                  class="truncate"
                  data-confirm="This will open the source media in a new tab. Are you sure?"
                >
                  <.url_icon url={version.source_url} class="h-4 w-4 inline mb-px" />
                  <%= version.source_url %>
                </a>
              </div>
            <% true -> %>
              <span class="text-neutral-400 px-4">
                &mdash;
              </span>
          <% end %>
        </td>
      <% end %>
    </tr>
    """
  end

  def search_form(%{changeset: c, query_params: _, socket: _, display: _} = assigns) do
    assigns =
      assign_new(assigns, :exclude, fn -> [] end)
      |> assign(:changeset, Map.put(c, :action, :validate))

    # We assign the ID to the top-level div to fix a Safari rendering bug

    ~H"""
    <div
      x-data="{ open: window.innerWidth >= 768 }"
      id={"search-form-component-#{Ecto.Changeset.get_field(@changeset, :display) |> to_string()}"}
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
                      "search-form-project-select-#{Ecto.Changeset.get_field(f.source, :project_id)}",
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
                    placeholder: "Search for anything...",
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
                x-data="{open: false}"
              >
                <div class="text-left z-10">
                  <div class="h-full flex gap-1">
                    <%= button type: "button", to: Routes.export_path(@socket, :create, @query_params),
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
                      href={"/incidents?display=#{Ecto.Changeset.get_field(f.source, :display, "cards")}"}
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
                  <.attr_filter id="status_filter" form={f} attr={Attribute.get_attribute(:status)} />
                  <.attr_filter
                    id="geolocation_filter"
                    form={f}
                    attr={Attribute.get_attribute(:geolocation)}
                  />
                  <.attr_filter id="date_filter" form={f} attr={Attribute.get_attribute(:date)} />
                  <.attr_filter
                    id="tags_filter"
                    form={f}
                    attr={
                      Attribute.get_attribute(:tags,
                        projects: Platform.Projects.list_projects_for_user(@current_user)
                      )
                    }
                  />
                  <.attr_filter
                    id="sensitive_filter"
                    form={f}
                    attr={Attribute.get_attribute(:sensitive)}
                  />
                </div>
              </div>
            </div>
          </section>
        </.form>
      </div>
    </div>
    """
  end

  def media_card_lazy(assigns) do
    ~H"""
    <div>
      <div class="fixed w-[350px] h-[190px] flex rounded-lg shadow-lg items-center bg-white justify-around -z-50">
        <div class="font-medium text-lg text-md p-4">
          <span class="animate-pulse">Loading...</span>
        </div>
      </div>
      <dynamic tag="iframe" src={"/incidents/#{@media.slug}/card"} width="350px" height="190px" />
    </div>
    """
  end

  def media_badges(%{media: %Media{} = media} = assigns) do
    assigns =
      assigns
      |> assign(:sensitive, Media.is_sensitive(media))
      |> assign_new(:only_status, fn -> false end)

    ~H"""
    <%= if not is_nil(@media.attr_status) and Map.get(assigns, :show_status, true) do %>
      <span class={"self-start badge whitespace-nowrap " <> Attribute.attr_color(:status, @media.attr_status)}>
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
        <%= @media.attr_status %>
      </span>
    <% end %>

    <%= if not @only_status do %>
      <%= if @sensitive do %>
        <%= for item <- @media.attr_sensitive || [] do %>
          <span class={"self-start badge whitespace-nowrap " <> Attribute.attr_color(:sensitive, @media.attr_sensitive)}>
            <%= item %>
          </span>
        <% end %>
      <% end %>

      <%= for item <- @media.attr_restrictions || [] do %>
        <!-- TODO: make this use Attribute.attr_color/2 -->
        <span class="self-start badge whitespace-nowrap ~warning">
          <%= item %>
        </span>
      <% end %>

      <%= if @media.attr_geolocation do %>
        <span class="self-start badge whitespace-nowrap ~neutral">
          Geolocated
        </span>
      <% end %>

      <%= if @media.attr_date do %>
        <span class="self-start badge whitespace-nowrap ~neutral">
          <%= @media.attr_date |> Calendar.strftime("%d %B %Y") %>
        </span>
      <% end %>
    <% end %>
    """
  end

  def media_card(%{media: %Media{} = media} = assigns) do
    assigns =
      assigns
      |> assign(:contributors, Material.contributors(media))
      |> assign(:sensitive, Media.is_sensitive(media))
      |> assign_new(:target, fn -> nil end)
      |> assign(:border, Map.get(assigns, :border, false))
      |> assign(:link, Map.get(assigns, :link, true))
      |> assign(:class, Map.get(assigns, :class, ""))

    ~H"""
    <a
      class={"flex items-stretch group flex-row bg-white overflow-hidden shadow rounded-lg justify-between min-h-[12rem] " <> (if @border, do: "border ", else: "") <> @class}
      href={if @link, do: "/incidents/#{@media.slug}", else: nil}
      target={@target}
    >
      <%= if Permissions.can_view_media?(@current_user, @media) do %>
        <div class="p-2 flex flex-col w-3/4 gap-2 relative">
          <section>
            <p class="font-mono text-xs text-gray-500 flex items-center gap-1">
              <%= Media.slug_to_display(@media) %>
              <%= if @media.has_subscription do %>
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
              <%= if @media.has_unread_notification do %>
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
              <%= if @media.deleted do %>
                <span class="badge ~critical @high uppercase">Deleted</span>
              <% end %>
            </p>
            <p class="text-gray-900 group-hover:text-gray-900">
              <%= @media.attr_description |> Utils.truncate(60) %>
            </p>
          </section>
          <section class="flex flex-wrap gap-1 self-start align-top">
            <.media_badges media={@media} />
          </section>
          <section class="mb-2 h-4" />
          <section class="bottom-0 mb-2 pr-4 w-full absolute flex gap-2 justify-between items-center">
            <.user_stack users={@contributors} />
            <p class="text-xs text-gray-500 flex items-center">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-3 w-3 mr-[3px] text-gray-400"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z"
                  clip-rule="evenodd"
                />
              </svg>
              <.rel_time time={@media.updated_at} />
            </p>
          </section>
        </div>

        <% thumb = Material.media_thumbnail(@media) %>
        <div class="block h-full min-h-[12rem] relative w-1/4 grayscale self-stretch overflow-hidden">
          <%= if thumb do %>
            <%= if Media.is_graphic(@media) do %>
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
    </div>
    """
  end

  def user_stack(assigns) do
    assigns = assign_new(assigns, :dynamic, fn -> true end) |> assign_new(:max, fn -> 5 end)

    ~H"""
    <div class="flex -space-x-1 relative z-0 place-items-end">
      <%= for user <- @users |> Enum.take(5) do %>
        <%= if @dynamic do %>
          <.popover class="inline">
            <img
              class={"relative z-30 inline-block rounded-full ring-2 " <> Map.get(assigns, :size_classes, "h-5 w-5") <> " " <> Map.get(assigns, :ring_class, "ring-white")}
              src={Accounts.get_profile_photo_path(user)}
              alt={"Profile photo for #{user.username}"}
              loading="lazy"
            />
            <:display>
              <.user_card user={user} />
            </:display>
          </.popover>
        <% else %>
          <img
            class={"relative z-30 inline-block rounded-full ring-2 " <> Map.get(assigns, :size_classes, "h-5 w-5") <> " " <> Map.get(assigns, :ring_class, "ring-white")}
            src={Accounts.get_profile_photo_path(user)}
            alt={"Profile photo for #{user.username}"}
            loading="lazy"
          />
        <% end %>
      <% end %>
      <%= if length(@users) > @max do %>
        <div
          class={"relative bg-gray-200 text-gray-700 text-xl rounded-full z-30 ring-2 flex items-center justify-center " <> Map.get(assigns, :size_classes, "h-5 w-5") <>" " <> Map.get(assigns, :ring_class, "ring-white")}
          data-tooltip={"Shared with #{length(@users) - 5} more user#{if length(@users) - 5 == 1, do: "", else: "s"}"}
        >
          <Heroicons.ellipsis_horizontal mini class="h-4 w-4" />
        </div>
      <% end %>
    </div>
    """
  end

  def document_preview(assigns) do
    assigns = assign_new(assigns, :description, fn -> "Document" end)

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
      <p class="text-sm font-medium text-center"><%= @file_name %></p>
      <p class="text-xs text-center"><%= @description %></p>
    </div>
    """
  end

  def media_version_display(%{version: version, media: media} = assigns) do
    artifact_to_show =
      cond do
        # If available, show a screenshot
        version.artifacts |> Enum.find(&(&1.type == :viewport)) != nil ->
          version.artifacts |> Enum.find(&(&1.type == :viewport))

        # Otherwise show the first artifact
        not Enum.empty?(version.artifacts) ->
          hd(version.artifacts)

        # Otherwise show nothing
        true ->
          nil
      end

    assigns =
      assigns
      |> assign(
        :artifact_to_show,
        version.status == :complete && artifact_to_show != nil
      )
      |> assign(:artifact, artifact_to_show)
      |> assign(:is_graphic, Media.is_graphic(media))
      # Whether to show controls for hiding, adding media (requires that the caller be able to handle the events)
      |> assign(:show_controls, Map.get(assigns, :show_controls, true))
      |> assign(:media_id, "version-#{version.id}-media")
      |> assign(:human_name, Material.get_human_readable_media_version_name(media, version))
      |> assign(:detail_url, "/incidents/#{media.slug}/detail/#{version.scoped_id}")

    ~H"""
    <section
      id={"version-#{@version.id}"}
      class="py-2 target:outline outline-2 outline-urge-600 rounded group outline-offset-2"
    >
      <.link patch={@detail_url}>
        <p class="font-mono text-sm">
          <%= @human_name %>
        </p>
      </.link>
      <div class="relative">
        <%= if @artifact_to_show do %>
          <.link
            patch={@detail_url}
            id={"artifact-#{@artifact.id}"}
            class="block h-40 overflow-hidden z-[1] border rounded-lg"
          >
            <%= cond do %>
              <% not @is_graphic and Platform.Utils.is_processable_media(@artifact.mime_type) -> %>
                <div class="grayscale highlight-block">
                  <img
                    src={Material.media_version_artifact_location(@artifact, version: :thumbnail)}
                    class="w-full object-cover scale-[1.1] origin-top"
                    height="160"
                    loading="lazy"
                  />
                </div>
              <% length(@version.artifacts) == 1 -> %>
                <div class="h-full w-full flex flex-col items-center justify-center">
                  <Heroicons.archive_box class="h-10 w-10 mb-2 text-neutral-500" />
                  <p class="text-neutral-700 text-center text-sm font-medium mb-2 uppercase">
                    <%= @artifact.file_location %>
                  </p>
                  <p class="text-neutral-500 text-center text-xs font-mono uppercase">
                    <%= @artifact.mime_type %>
                  </p>
                </div>
              <% true -> %>
                <div class="h-full w-full flex flex-col items-center justify-center p-2">
                  <Heroicons.archive_box class="h-10 w-10 mb-2 text-neutral-500" />
                  <p class="font-medium text-center text-sm">
                    <%= Material.get_media_version_title(@version) |> Utils.truncate(40) %>
                  </p>
                  <p class="text-neutral-500 text-sm">
                    <%= length(@version.artifacts) %>
                    <%= if length(@version.artifacts) != 1, do: "artifacts", else: "artifact" %>
                  </p>
                </div>
            <% end %>
            <div class="border rounded-lg opacity-0 overflow-hidden group-hover:opacity-100 group-focus:opacity-100 group-focus-within:opacity-100 block absolute inset-0 backdrop-blur-sm transition bg-white/50 flex flex-col gap-2 items-center justify-center w-full h-full">
              <Heroicons.plus_circle mini class="h-5 w-5 text-neutral-600" />
              <span class="text-neutral-600">View details and artifacts</span>
            </div>
          </.link>
        <% else %>
          <div class="w-full h-40 bg-neutral-50 border rounded-lg flex items-center justify-around">
            <%= cond do %>
              <% @version.status == :pending -> %>
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
                    href={@version.source_url}
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
              <% @version.source_url != nil -> %>
                <a
                  target="_blank"
                  href={@version.source_url}
                  rel="nofollow"
                  class="text-center w-48 block"
                  data-confirm="This link will open an external site in a new tab. Are you sure?"
                >
                  <.url_icon url={@version.source_url} class="mx-auto h-10 w-10 shadow-sm" />
                  <h3 class="mt-2 break-all font-medium text-gray-900 text-sm">External Media</h3>
                  <p class="mt-1 text-gray-500 text-sm">
                    Unable to archive this media automatically.
                  </p>
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
              <% true -> %>
                <div class="text-center w-48">
                  <Heroicons.exclamation_circle class="mx-auto h-8 w-8 text-gray-400" />
                  <h3 class="mt-2 font-medium text-gray-900 text-sm">Processing Error</h3>
                  <p class="mt-1 text-gray-500 text-sm">
                    Unable to process this source material
                  </p>
                </div>
            <% end %>
          </div>
        <% end %>
      </div>
      <div class="flex gap-1 mt-1 text-sm max-w-full items-center justify-between">
        <span class="flex items-center gap-2 overflow-hidden">
          <%= if @version.status != :error and @version.source_url != nil do %>
            <.url_icon url={@version.source_url} class="h-6" />
          <% end %>
          <%= if @version.source_url != nil do %>
            <a
              class="text-neutral-600 truncate"
              href={@version.source_url}
              target="_blank"
              data-confirm="This link will open an external site in a new tab. Are you sure?"
            >
              <%= @version.source_url %>
            </a>
          <% end %>
          <%= if @version.upload_type == :user_provided do %>
            <span class="badge ~neutral self-start shrink-0">User Upload</span>
          <% end %>
          <%= if @version.status == :error and @show_controls do %>
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
        <%= if @artifact_to_show or @show_controls do %>
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
                  <a
                    :if={not is_nil(@version.source_url)}
                    target="_blank"
                    href={@version.source_url}
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
                  <button
                    :if={not is_nil(@version.source_url)}
                    type="button"
                    rel="nofollow"
                    role="menuitem"
                    title="Copy Hash Information"
                    class="text-gray-700 px-2 py-2 text-sm flex items-center gap-2 hover:bg-gray-100 w-full"
                    x-data
                    x-on:click={
                      "window.setClipboard(" <>
                        Jason.encode!(@version.source_url) <>
                        ")"
                    }
                  >
                    <Heroicons.link mini class="w-5 h-5 text-neutral-500" /> Copy URL
                  </button>
                  <%= if @version.visibility == :visible and @show_controls do %>
                    <button
                      type="button"
                      data-confirm="Are you sure you want to change the visibility of this media for all members of this project?"
                      phx-click="set_media_visibility"
                      phx-value-version={@version.id}
                      phx-value-state="hidden"
                      class="text-gray-700 px-2 py-2 text-sm flex items-center gap-2 hover:bg-gray-100 w-full"
                      title="Minimize"
                      data-tooltip="Minimized source material can be viewed by all project members."
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
                      Minimize
                    </button>
                  <% end %>
                  <%= if @version.visibility == :hidden and @show_controls do %>
                    <button
                      type="button"
                      data-confirm="Are you sure you want to change the visibility of this media?"
                      phx-click="set_media_visibility"
                      phx-value-version={@version.id}
                      phx-value-state="visible"
                      class="text-gray-700 px-2 py-2 text-sm flex items-center gap-2 hover:bg-gray-100 w-full"
                      title="Unminimize"
                      data-tooltip="Minimized source material can be viewed by all project members."
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
                      Unminimize
                    </button>
                  <% end %>
                  <%= if Permissions.can_rearchive_media_version?(@current_user, @version) do %>
                    <button
                      type="button"
                      data-confirm="Are you sure you want to rearchive this media?"
                      phx-click="rearchive_media_version"
                      phx-value-version={@version.id}
                      phx-value-state="visible"
                      class="text-gray-700 px-2 py-2 text-sm flex items-center gap-2 hover:bg-gray-100 w-full"
                      title="Rearchive"
                    >
                      <Heroicons.arrow_path mini class="w-5 h-5 text-neutral-500" /> Rearchive
                    </button>
                  <% end %>
                  <%= if @show_controls and Platform.Permissions.can_change_media_version_visibility?(@current_user, @version) do %>
                    <button
                      type="button"
                      data-confirm="Are you sure you want to change the visibility of this media?"
                      phx-click="set_media_visibility"
                      phx-value-version={@version.id}
                      phx-value-state={
                        if @version.visibility == :removed, do: "visible", else: "removed"
                      }
                      data-tooltip="Removed source material can only be viewed by project owners and managers."
                      title={if @version.visibility == :removed, do: "Undo Removal", else: "Remove"}
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
                      <%= if @version.visibility == :removed, do: "Undo Removal", else: "Remove" %>
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

  def interactive_textarea(assigns) do
    assigns =
      assigns
      |> assign_new(:required, fn -> false end)

    ~H"""
    <div id={@id} class="my-[2px] px-2" phx-update="ignore">
      <div id={"child-#{@id}"} x-data>
        <%= textarea(@form, @name,
          disabled: @disabled,
          class: "!hidden",
          id: "textarea-#{@id}",
          required: @required
        ) %>
        <div>
          <textarea
            interactive-mentions
            rows={@rows}
            placeholder={@placeholder}
            class={@class}
            disabled={@disabled}
            required={@required}
            data-feedback={"textarea-#{@id}"}
          ><%= Ecto.Changeset.get_field(@form.source, :explanation) %></textarea>
        </div>
      </div>
    </div>
    """
  end

  def dropdown(assigns) do
    ~H"""
    <div
      class="relative inline-block text-left z-[10000]"
      x-data="{open: false}"
      x-on:click.away="open = false"
    >
      <div>
        <button
          type="button"
          class="inline-flex w-full justify-center gap-x-1.5 text-sm text-gray-900"
          aria-haspopup="true"
          x-on:click="open = !open"
        >
          <%= @label %>
          <svg
            class="-mr-1 h-5 w-5 text-gray-400"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z"
              clip-rule="evenodd"
            />
          </svg>
        </button>
      </div>
      <div
        class="absolute right-0 z-10 mt-2 w-56 origin-top-right rounded-md bg-white shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none"
        role="menu"
        x-transition
        aria-orientation="vertical"
        tabindex="-1"
        x-show="open"
      >
        <div class="py-1" role="none">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    </div>
    """
  end

  def interactive_urldrop(assigns) do
    ~H"""
    <div id={@id} phx-update="ignore">
      <div id={"child-#{@id}"} x-data>
        <%= textarea(@form, @name,
          class: "!hidden",
          id: "textarea-#{@id}"
        ) %>
        <div>
          <textarea
            interactive-urls
            placeholder={@placeholder}
            class={(@class) <> " overflow-hidden break-all !pr-1"}
            data-feedback={"textarea-#{@id}"}
          />
        </div>
      </div>
    </div>
    """
  end

  def edit_attributes(assigns) do
    core_attributes = assigns[:attrs] |> Enum.filter(&(&1.schema_field != :project_attributes))
    project_attributes = assigns[:attrs] |> Enum.filter(&(&1.schema_field == :project_attributes))

    assigns =
      assigns
      |> assign(:core_attributes, core_attributes)
      |> assign(:project_attributes, project_attributes)
      |> assign_new(:optional, fn -> false end)

    ~H"""
    <section class="flex flex-col gap-8">
      <%= for attr <- @core_attributes do %>
        <.edit_attribute
          attr={attr}
          form={@form}
          media_slug={@media_slug}
          media={@media}
          optional={@optional}
        />
      <% end %>

      <%= for sub_f <- inputs_for(@form, :project_attributes), not is_nil(Enum.find(@project_attributes, &(&1.name == input_value(sub_f, :id)))) do %>
        <% attr = @project_attributes |> Enum.find(&(&1.name == input_value(sub_f, :id))) %>
        <div>
          <%= hidden_input(sub_f, :project_id) %>
          <%= hidden_input(sub_f, :id) %>
          <.edit_attribute
            attr={attr}
            form={sub_f}
            media_slug={@media_slug}
            media={@media}
            optional={@optional}
          />
        </div>
      <% end %>
    </section>
    """
  end

  defp edit_attribute(%{attr: attr, form: form, media_slug: slug} = assigns) do
    assigns =
      assigns
      |> assign(
        :label,
        attr.label <> if(Map.get(assigns, :optional, false), do: " (Optional)", else: "")
      )
      # Shorthands
      |> assign(:slug, slug)
      |> assign(:f, form)
      |> assign(
        :schema_field,
        if(attr.schema_field == :project_attributes, do: :value, else: attr.schema_field)
      )

    ~H"""
    <article x-data="{user_loc: null}" id={"editor-" <> (@attr.name |> to_string())}>
      <%= case @attr.type do %>
        <% :text -> %>
          <%= label(@f, @schema_field, @label) %>
          <%= case @attr.input_type || :textarea do %>
            <% :textarea -> %>
              <%= textarea(@f, @schema_field, rows: 3, phx_debounce: 200) %>
            <% :short_text -> %>
              <%= text_input(@f, @schema_field, phx_debounce: 200) %>
          <% end %>
          <%= error_tag(@f, @schema_field) %>
        <% :select -> %>
          <%= label(@f, @schema_field, @label) %>
          <%= error_tag(@f, @schema_field) %>
          <div phx-update="ignore" id={"attr_select_#{@slug}_#{@attr.name}"}>
            <%= select(
              @f,
              @schema_field,
              if(@attr.required, do: [], else: ["[Unset]": nil]) ++
                Attribute.options(
                  @attr,
                  if(is_nil(@media), do: nil, else: Material.get_attribute_value(@media, @attr))
                ),
              id: "attr_select_#{@slug}_#{@attr.name}_input",
              data_descriptions: Jason.encode!(@attr.option_descriptions || %{}),
              data_privileged: Jason.encode!(@attr.privileged_values || [])
            ) %>
          </div>
        <% :multi_select -> %>
          <%= label(@f, @schema_field, @label) %>
          <%= error_tag(@f, @schema_field) %>
          <div phx-update="ignore" id={"attr_multi_select_#{@slug}_#{@attr.name}"}>
            <%= multiple_select(
              @f,
              @schema_field,
              Attribute.options(
                @attr,
                if(is_nil(@media), do: nil, else: Material.get_attribute_value(@media, @attr))
              ),
              id: "attr_multi_select_#{@slug}_#{@attr.name}_input",
              data_descriptions: Jason.encode!(@attr.option_descriptions || %{}),
              data_privileged: Jason.encode!(@attr.privileged_values || []),
              data_allow_user_defined_options: Attribute.allow_user_defined_options(@attr)
            ) %>
          </div>
        <% :location -> %>
          <div class="space-y-4">
            <div>
              <%= label(@f, :location, @label <> " (latitude, longitude)") %>
              <%= text_input(@f, :location,
                placeholder: "Comma-separated coordinates (lat, lon).",
                novalidate: true,
                phx_debounce: 500,
                "x-on:input": "user_loc = $event.target.value"
              ) %>
              <%= error_tag(@f, :location) %>
            </div>
            <%= error_tag(@f, @schema_field) %>
          </div>
        <% :time -> %>
          <%= label(@f, @schema_field, @label) %>
          <div class="flex items-center gap-2 ts-ignore sm:w-64 apply-a17t-fields">
            <%= time_select(@f, @schema_field,
              hour: [prompt: "[Unset]"],
              minute: [prompt: "[Unset]"],
              class: "select",
              phx_debounce: 500
            ) %>
          </div>
          <p class="support">
            To unset this attribute, set both the hour and minute fields to [Unset].
          </p>
          <%= error_tag(@f, @schema_field) %>
        <% :date -> %>
          <%= label(@f, @schema_field, @label) %>
          <div class="flex items-center gap-2 ts-ignore apply-a17t-fields">
            <%= date_select(@f, @schema_field,
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
          <%= error_tag(@f, @schema_field) %>
      <% end %>
      <%= if @attr.type == :location do %>
        <a
          class="support text-urge-700 underline mt-4"
          target="_blank"
          x-show="user_loc != null && user_loc.length > 0"
          x-bind:href="'https://maps.google.com/maps?q=' + (user_loc || '').replace(' ', '')"
        >
          Preview <span class="font-bold" x-text="user_loc"></span> on Google Maps
        </a>
      <% end %>
    </article>
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

  defp user_name_display(assigns) do
    ~H"""
    <a
      class="font-medium text-gray-900 hover:text-urge-600 inline-flex gap-1 flex-wrap"
      href={if is_nil(@user), do: "#", else: "/profile/#{@user.username}"}
    >
      <%= if is_nil(@user) do %>
        [System]
      <% else %>
        <%= @user.username %>
        <%= if Accounts.is_admin(@user) do %>
          <span class="font-normal text-xs badge ~critical self-center">Admin</span>
        <% end %>
        <%= if String.length(@user.flair) > 0 do %>
          <span class="font-normal text-xs badge ~urge self-center"><%= @user.flair %></span>
        <% end %>
      <% end %>
    </a>
    """
  end

  def user_card(%{user: %Accounts.User{} = _} = assigns) do
    ~H"""
    <.link navigate={"/profile/" <> @user.username}>
      <div class="flex items-center gap-4 p-2 overflow-hidden">
        <div class="w-12">
          <img
            class="relative z-30 inline-block h-12 w-12 rounded-full ring-2 ring-white"
            src={Accounts.get_profile_photo_path(@user)}
            alt={"Profile photo for #{@user.username}"}
          />
        </div>
        <div class="flex flex-col gap-1 max-w-full">
          <.user_name_display user={@user} />
          <p class="text-neutral-600 break-words max-w-full">
            <%= if is_nil(@user.bio) or String.length(@user.bio |> String.trim()) == 0,
              do: "",
              else: @user.bio %>
          </p>
        </div>
      </div>
    </.link>
    """
  end

  def user_text(%{user: %Accounts.User{} = _} = assigns) do
    ~H"""
    <.popover class="inline">
      <.user_name_display user={@user} />
      <:display>
        <%= if is_nil(@user) do %>
          This is an administrative user.
        <% else %>
          <.user_card user={@user} />
        <% end %>
      </:display>
    </.popover>
    """
  end

  def media_text(assigns) do
    ~H"""
    <.popover class="inline overflow-hidden" no_pad={true}>
      <span class={"text-button transition inline-block mr-2 " <> Map.get(assigns, :class, "text-gray-800")}>
        <.link navigate={"/incidents/" <> @media.slug}>
          <%= Media.slug_to_display(@media) %> &nearr;
        </.link>
      </span>
      <:display>
        <div class="-m-3 w-[350px] h-[190px] rou@nded">
          <.media_card_lazy media={@media} />
        </div>
      </:display>
    </.popover>
    """
  end

  def floating_bottom(assigns) do
    ~H"""
    <section class="fixed bottom-0 inset-x-0 pb-2 sm:pb-5 z-50 flex flex-col flex-reverse">
      <%= render_slot(@inner_block) %>
    </section>
    """
  end

  def floating_warning(assigns) do
    ~H"""
    <section class="inset-x-0 pb-2 sm:pb-5 z-50">
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
    <section class="inset-x-0 pb-2 sm:pb-5 z-50">
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

    assigns = assign(assigns, :site_key, site_key)

    ~H"""
    <article>
      <div
        id="hcaptcha-demo"
        class="h-captcha"
        data-sitekey={@site_key}
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
        Atlos is <a href="https://github.com/atlosdotorg/atlos" class="underline">open source</a>.
      </p>
      <p>
        By using Atlos, you agree to our
        <a href="https://github.com/atlosdotorg/atlos/blob/main/policy/TERMS_OF_USE.md">
          <span class="underline">Terms</span>
        </a>
        and <a href="https://github.com/atlosdotorg/atlos/blob/main/policy/PRIVACY_POLICY.md"><span class="underline">Privacy Policy</span></a>.
      </p>
    </div>
    """
  end

  def footer(assigns) do
    ~H"""
    <footer class="place-self-center max-w-lg mx-auto mt-8 text-gray-500 text-xs">
      <div class="grid grid-cols-3 text-center gap-4 md:flex md:justify-between">
        <a href="https://github.com/atlosdotorg/atlos" class="hover:text-gray-600" target="_blank">
          Source Code
        </a>
        <a
          href="https://github.com/atlosdotorg/atlos/blob/main/policy/TERMS_OF_USE.md"
          class="hover:text-gray-600 transition"
          target="_blank"
        >
          Terms
        </a>
        <a
          href="https://github.com/atlosdotorg/atlos/blob/main/policy/PRIVACY_POLICY.md"
          class="hover:text-gray-600 transition"
          target="_blank"
        >
          Privacy
        </a>
        <a
          href="https://github.com/atlosdotorg/atlos/blob/main/policy/RESILIENCE.md"
          class="hover:text-gray-600 transition"
          target="_blank"
        >
          Resilience
        </a>
        <a
          href="https://github.com/atlosdotorg/atlos/discussions"
          class="hover:text-gray-600 transition"
          target="_blank"
        >
          Feedback
        </a>
        <a href="mailto:contact@atlos.org" class="hover:text-gray-600 transition">Contact</a>
      </div>
    </footer>
    """
  end

  attr(:project, Platform.Projects.Project)
  slot(:actions)

  def project_bar(assigns) do
    ~H"""
    <div class="border-b bg-white overflow-hidden border-b flex justify-between">
      <div class="flex items-center justify-between gap-4 w-full lg:max-w-screen-xl px-6 py-2 lg:mx-auto">
        <%= if is_nil(@project) do %>
          <div class="text-neutral-700 pb-1 pt-2 px-3 gap-1 hover:bg-neutral-100 rounded transition">
            <p class="text-xs text-neutral-500">Project</p>
            <p class="font-medium">
              <div class="inline-flex items-center font-medium">
                No Project
              </div>
            </p>
          </div>
        <% else %>
          <.link
            href={"/projects/#{@project.id}"}
            class="text-neutral-700 pb-1 pt-2 px-3 gap-1 hover:bg-neutral-100 rounded transition"
          >
            <p class="text-xs text-neutral-500">Project</p>
            <p class="font-medium">
              <div class="inline-flex items-center font-medium">
                <%= @project.name %>
                <span style={"color: #{@project.color}"}>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                    class="w-5 h-5 ml-px"
                  >
                    <circle cx="10" cy="10" r="5" />
                  </svg>
                </span>
              </div>
            </p>
          </.link>
        <% end %>
        <div>
          <.user_stack users={@project.memberships |> Enum.map(& &1.user)} size_classes="h-7 w-7" />
        </div>
      </div>
    </div>
    """
  end

  def project_card_inner(assigns) do
    # Like <.project_card> below, but without a link.
    ~H"""
    <div class="bg-white rounded-lg shadow overflow-hidden p-4 flex-col gap-2 min-w-[15rem]">
      <p class="font-mono text-xs text-neutral-600"><%= @project.code %></p>
      <p class="font-medium text-lg inline-flex items-center">
        <%= @project.name %>
        <span style={"color: #{@project.color}"}>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            class="w-5 h-5 ml-px"
          >
            <circle cx="10" cy="10" r="6" />
          </svg>
        </span>
      </p>
      <% total_incidents = Material.total_media_in_project!(@project) %>
      <p class="support font-base text-neutral-600">
        <%= total_incidents |> Formatter.format_number() %> <%= if total_incidents == 1,
          do: "incident",
          else: "incidents" %>
      </p>
    </div>
    """
  end

  def project_card(assigns) do
    ~H"""
    <.link href={"/projects/#{@project.id}"}>
      <.project_card_inner project={@project} />
    </.link>
    """
  end

  attr(:map_data, :list)

  def map_events(assigns) do
    # Note: interactivity is setup by `app.js` when initializing the map client-side

    map_data = assigns[:map_data]

    {lat, lon} =
      with [first | _] <- map_data,
           %{lat: lat, lon: lon} when -90 <= lat and 90 > lat and -180 <= lon and 180 >= lon <-
             first do
        first = map_data |> Enum.at(0)
        {first[:lat], first[:lon]}
      else
        _ -> {35, 35}
      end

    assigns = assign(assigns, :lat, lat) |> assign(:lon, lon)

    ~H"""
    <map-events
      lat={@lat}
      lon={@lon}
      zoom="3"
      id="map_events"
      container-id="map_events_container"
      data={Jason.encode!(@map_data)}
    />
    <section
      class="fixed relative h-screen w-screen left-0 top-0 bottom-0"
      id="map"
      phx-update="ignore"
      x-data="{style: 'overview'}"
    >
      <map-container id="map_events_container" x-ref="container" />
      <button class="rounded-full bg-white border shadow h-10 w-10 flex items-center justify-around fixed bottom-0 right-0 mb-8 mr-4 layer-toggle-button">
        <Heroicons.square_3_stack_3d mini class="opacity-75 h-5 w-5" />
      </button>
    </section>
    """
  end

  attr(:id, :string)
  attr(:next_link, :string)
  attr(:prev_link, :string)
  attr(:pagination_metadata, :map)
  attr(:pagination_index, :integer)
  attr(:currently_displayed_results, :integer)

  def pagination_controls(assigns) do
    ~H"""
    <nav class="flex items-center justify-center sm:justify-between w-full" aria-label="Pagination">
      <div class="flex flex-1 gap-2 md:mr-8" phx-hook="ScrollToTop" id={@id}>
        <%= if not is_nil(@pagination_metadata.before) do %>
          <.link patch={@prev_link} class="text-button">
            <Heroicons.arrow_left mini class="h-6 w-6" />
            <span class="sr-only">Previous</span>
          </.link>
        <% else %>
          <span class="cursor-not-allowed opacity-75 text-neutral-600">
            <Heroicons.arrow_left mini class="h-6 w-6" />
            <span class="sr-only">Previous</span>
          </span>
        <% end %>
        <%= if not is_nil(@pagination_metadata.after) do %>
          <.link patch={@next_link} class="text-button">
            <Heroicons.arrow_right mini class="h-6 w-6" />
            <span class="sr-only">Next</span>
          </.link>
        <% else %>
          <span class="cursor-not-allowed opacity-75 text-neutral-600">
            <Heroicons.arrow_right mini class="h-6 w-6" />
            <span class="sr-only">Next</span>
          </span>
        <% end %>
      </div>
      <div class="hidden sm:block">
        <p class="text-sm text-gray-700">
          Showing results
          <span class="font-medium">
            <%= (@pagination_index * @pagination_metadata.limit + 1) |> Formatter.format_number() %>
          </span>
          to
          <span class="font-medium">
            <%= (@pagination_index * @pagination_metadata.limit +
                   @currently_displayed_results)
            |> Formatter.format_number() %>
          </span>
          of
          <span class="font-medium">
            <%= @pagination_metadata.total_count |> Formatter.format_number() %><%= if @pagination_metadata.total_count_cap_exceeded,
              do: "+",
              else: "" %>
          </span>
        </p>
      </div>
    </nav>
    """
  end
end
