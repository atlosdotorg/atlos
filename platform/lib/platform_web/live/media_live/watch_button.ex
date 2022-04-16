defmodule PlatformWeb.MediaLive.WatchButton do
  use PlatformWeb, :live_component
  alias Platform.Accounts
  alias Platform.Material

  def update(
        %{media: %Material.Media{} = media, current_user: %Accounts.User{} = user} = assigns,
        socket
      ) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:watching, Material.get_watching(media, user))
     |> assign(:count, Material.total_watching!(media))
   }
  end

  def handle_event("watch", _input, socket) do
    case Material.watch_media(socket.assigns.media, socket.assigns.current_user) do
      {:ok, watching} ->
        {:noreply,
         socket
         |> assign(:watching, watching) |> assign(:count, Material.total_watching!(socket.assigns.media))}

      {:error, _} ->
        # TODO: throw some kind of error?
        {:noreply, socket}
    end
  end

  def handle_event("unwatch", _input, socket) do
    case Material.unwatch_media(socket.assigns.media, socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:watching, nil) |> assign(:count, Material.total_watching!(socket.assigns.media))}

      {:error, _} ->
        # TODO: throw some kind of error?
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <%= if @watching do %>
        <button type="button" class="button ~urge @high" phx-click="unwatch" phx-target={@myself}>
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
          </svg>

          Watching
          <span class="ml-2 bg-urge-800 text-xs rounded-full px-2 py-px">
            <%= @count %>
          </span>
        </button>
      <% else %>
        <button type="button" class="base-button" phx-click="watch" phx-target={@myself}>
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-1 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
          </svg>
          Watch
          <span class="ml-2 bg-neutral-200 text-xs rounded-full px-2 py-px">
            <%= @count %>
          </span>
        </button>
      <% end %>
    </div>
    """
  end
end
