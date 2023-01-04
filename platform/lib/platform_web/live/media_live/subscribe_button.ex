defmodule PlatformWeb.MediaLive.SubscribeButton do
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
     |> assign(:subscription, Material.get_subscription(media, user))
     |> assign(:count, Material.total_subscribed!(media))}
  end

  def handle_event("subscribe", _input, socket) do
    case Material.subscribe_user(socket.assigns.media, socket.assigns.current_user) do
      {:ok, subscription} ->
        {:noreply,
         socket
         |> assign(:subscription, subscription)}

      {:error, _} ->
        # TODO: throw some kind of error?
        {:noreply, socket}
    end
  end

  def handle_event("unsubscribe", _input, socket) do
    case Material.unsubscribe_user(socket.assigns.media, socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> assign(:subscription, nil)}

      :error ->
        # TODO: throw some kind of error?
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex items-center">
      <%= if @subscription do %>
        <button
          type="button"
          class="text-button text-sm inline-flex items-center gap-px"
          phx-click="unsubscribe"
          phx-target={@myself}
        >
          <Heroicons.check mini class="h-5 w-5" /> Subscribed
        </button>
      <% else %>
        <button
          type="button"
          class="text-button text-sm inline-flex items-center gap-px"
          phx-click="subscribe"
          phx-target={@myself}
        >
          <Heroicons.plus_small mini class="h-5 w-5" /> Subscribe
        </button>
      <% end %>
    </div>
    """
  end
end
