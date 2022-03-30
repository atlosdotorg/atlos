defmodule PlatformWeb.MediaLive.Show do
  use PlatformWeb, :live_view
  alias Platform.Material
  alias Material.Media.Attribute

  def mount(%{"slug" => slug} = _params, _session, socket) do
    {:ok, socket |> assign(:slug, slug) |> assign_media()}
  end

  defp attr_entry(assigns) do
    attr = Attribute.get_attribute(assigns.name)
    ~H"""
    <div class="py-4 sm:grid sm:py-5 sm:grid-cols-3 sm:gap-4">
        <dt class="text-sm font-medium text-gray-500 mt-1"><%= attr.label %></dt>
        <dd class="mt-1 flex text-sm text-gray-900 sm:mt-0 sm:col-span-2">
            <span class="flex-grow">
                <%= case attr.type do %>
                <% :text -> %>
                <div class="mr-1 my-1 inline-block">
                  <%= Map.get(@media, attr.schema_field) %>
                </div>
                <% :multi_select -> %>
                  <%= for item <- Map.get(@media, attr.schema_field) do %>
                      <span class="chip ~neutral mr-1 mb-1"><%= item %></span>
                  <% end %>
                <% end %>
            </span>
            <span class="ml-4 flex-shrink-0">
                <button type="button" class="text-button mt-1">Update</button>
            </span>
        </dd>
    </div>
    """
  end

  defp assign_media(socket) do
    with %Material.Media{} = media <- Material.get_full_media_by_slug(socket.assigns.slug) do
      socket |> assign(:media, media)
    else
      nil ->
        socket
        |> put_flash(:error, "This media does not exist or is not publicly visible.")
        |> redirect(to: "/")
    end
  end
end
