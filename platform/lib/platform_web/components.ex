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
      <div class="px-4 py-5 sm:px-6">
        <%= render_slot(@header) %>
      </div>
      <% end %>
      <div class="px-4 py-5 sm:p-6">
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
        </div>
      </div>
    </div>
    """
  end
end
