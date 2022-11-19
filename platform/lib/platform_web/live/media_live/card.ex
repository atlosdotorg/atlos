defmodule PlatformWeb.MediaLive.Card do
  use Phoenix.LiveView,
    layout: {PlatformWeb.LayoutView, :live_iframe}

  import PlatformWeb.Components
  alias Platform.Material

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"slug" => slug} = _params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:slug, slug)
     |> assign(:title, "Incident #{slug}")
     |> assign(:iframe_mode, true)
     |> assign(:_no_background, true)
     |> assign(:media, Material.get_full_media_by_slug(slug))}
  end

  def render(assigns) do
    ~H"""
    <div class="h-full w-full">
      <.media_card class="border" media={@media} current_user={@current_user} />
    </div>
    """
  end
end
