defmodule PlatformWeb.MediaLive.Show do
  use PlatformWeb, :live_view
  alias Platform.Material

  def mount(%{"slug" => slug} = _params, _session, socket) do
    {:ok, socket |> assign(:slug, slug) |> assign_media()}
  end

  defp assign_media(socket) do
    with %Material.Media{} = media <- Material.get_full_media_by_slug(socket.assigns.slug) do
      socket |> assign(:media, media)
    else
      nil -> socket |> put_flash(:error, "This media does not exist or is not publicly visible.") |> redirect(to: "/")
    end
  end
end
