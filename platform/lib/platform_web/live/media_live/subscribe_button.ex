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
     |> assign(:count, Material.total_subscribed!(media))
     |> assign_new(:subscribed_label, fn -> "Subscribed" end)
     |> assign_new(:not_subscribed_label, fn -> "Subscribe" end)
     |> assign_new(:show_icon, fn -> true end)
     |> assign_new(:js_on_subscribe, fn -> "" end)
     |> assign_new(:js_on_unsubscribe, fn -> "" end)
     |> assign_new(:subscribed_classes, fn -> "" end)
     |> assign_new(:not_subscribed_classes, fn -> "" end)}
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
          class={"text-sm inline-flex items-center gap-px " <> @subscribed_classes}
          phx-click="unsubscribe"
          phx-target={@myself}
          x-on:click={@js_on_unsubscribe}
        >
          <%= if @show_icon do %>
            <Heroicons.check mini class="h-5 w-5" />
          <% end %>
          <%= @subscribed_label %>
        </button>
      <% else %>
        <button
          type="button"
          class={"text-sm inline-flex items-center gap-px " <> @not_subscribed_classes}
          phx-click="subscribe"
          phx-target={@myself}
          x-on:click={@js_on_subscribe}
        >
          <%= if @show_icon do %>
            <Heroicons.plus_small mini class="h-5 w-5" />
          <% end %>
          <%= @not_subscribed_label %>
        </button>
      <% end %>
    </div>
    """
  end
end
