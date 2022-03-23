defmodule PlatformWeb.Components do
  use Phoenix.Component
  use Phoenix.HTML

  def navlink(%{request_path: path, to: to} = assigns) do
    # TODO(miles): check for active tab
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

  def card(assigns) do
    assigns =
      assigns
      |> assign_new(:header, fn -> [] end)

    ~H"""
    <div class="bg-white overflow-hidden shadow rounded-lg divide-y divide-gray-200 max-w-xl">
      <%= unless Enum.empty?(@header) do %>
      <div class="py-4 px-5 sm:py-5">
        <%= render_slot(@header) %>
      </div>
      <% end %>
      <div class="py-4 px-5 sm:py-5">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  def notification(assigns) do
    assigns =
      assigns
      |> assign_new(:title, fn -> "" end)

    icon =
      case assigns[:type] do
        _ ->
          ~H"""
          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-info-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          """
      end

    ~H"""
    <div class="max-w-sm w-full bg-white shadow-lg rounded-lg pointer-events-auto ring-1 ring-black ring-opacity-5 overflow-hidden">
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
    <div class="hidden w-28 bg-neutral-700 overflow-y-auto md:block">
        <div class="w-full py-6 flex flex-col items-center">
            <%= link to: "/", class: "flex flex-col items-center text-white" do %>
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <span class="text-white uppercase font-bold">Atlos</span>
            <% end %>
            <div class="flex-1 mt-6 w-full px-2 space-y-1">
            <.navlink to="/new" label="New" request_path={@path}>
                <svg class="text-white group-hover:text-white h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
                </svg>
            </.navlink>

            <a href="#" class="text-neutral-100 hover:bg-neutral-800 hover:text-white group w-full p-3 rounded-md flex flex-col items-center text-xs font-medium">
                <svg class="text-neutral-300 group-hover:text-white h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
                </svg>
                <span class="mt-2">Queue</span>
            </a>

            <a href="#" class="text-neutral-100 hover:bg-neutral-800 hover:text-white group w-full p-3 rounded-md flex flex-col items-center text-xs font-medium">
                <svg class="text-neutral-300 group-hover:text-white h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <span class="mt-2">All Media</span>
            </a>

            <a href="#" class="text-neutral-100 hover:bg-neutral-800 hover:text-white group w-full p-3 rounded-md flex flex-col items-center text-xs font-medium">
                <svg class="text-neutral-300 group-hover:text-white h-6 w-6" xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
                </svg>
                <span class="mt-2">Watchlist</span>
            </a>

            <.navlink to="/notifications" label="Notifications" request_path={@path}>
                <svg class="text-neutral-300 group-hover:text-white h-6 w-6" xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                </svg>
            </.navlink>

            <.navlink to="/settings" label="Settings" request_path={@path}>
                <svg class="text-neutral-300 group-hover:text-white h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
            </.navlink>
            </div>
        </div>
    </div>
    """
  end

  def stepper(%{options: options, active: active} = assigns) do
    active_index = Enum.find_index(options, &String.equivalent?(&1, active))

    ~H"""
    <nav aria-label="Progress">
      <ol role="list" class="border border-gray-300 rounded-md divide-y divide-gray-300 md:flex md:divide-y-0 bg-white">
        <%= for {item, index} <- Enum.with_index(options) do %>
          <li class="relative md:flex-1 md:flex">
            <%= if index < active_index do %>
              <!-- Completed Step -->
              <div class="group flex items-center w-full">
                <span class="px-6 py-4 flex items-center text-sm font-medium">
                  <span class="flex-shrink-0 w-10 h-10 flex items-center justify-center bg-urge-600 rounded-full ">
                    <!-- Heroicon name: solid/check -->
                    <svg class="w-6 h-6 text-white" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
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
                <svg class="h-full w-full text-gray-300" viewBox="0 0 22 80" fill="none" preserveAspectRatio="none">
                  <path d="M0 -2L20 40L0 82" vector-effect="non-scaling-stroke" stroke="currentcolor" stroke-linejoin="round" />
                </svg>
              </div>
            <% end %>
          </li>
        <% end %>
      </ol>
    </nav>
"""
  end
end
