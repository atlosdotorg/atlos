defmodule PlatformWeb.SubscriptionsLive.Index do
  use PlatformWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:title, "Manage Subscriptions")}
  end

  def render(assigns) do
    ~H"""
    <article class="w-full px-4 md:px-8">
      <div class="mb-8">
        <h1 class="page-header">
          My Subscriptions
        </h1>
      </div>
      <.live_component
        module={PlatformWeb.MediaLive.PaginatedMediaList}
        id="media-list"
        show_subscription_button={true}
        current_user={@current_user}
        query_params={%{"only_subscribed" => true}}
      />
    </article>
    """
  end
end
