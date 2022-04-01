defmodule PlatformWeb.MediaLive.Show do
  use PlatformWeb, :live_view
  alias Platform.Material
  alias Material.Attribute

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"slug" => slug} = params, uri, socket) do
    {:noreply,
     socket
     |> assign(:slug, slug)
     |> assign(:attribute, Map.get(params, "attribute"))
     |> assign_media()}
  end

  defp attr_entry(assigns) do
    attr = Attribute.get_attribute(assigns.name)

    ~H"""
    <span class="flex-grow gap-1 flex flex-wrap">
        <%= case attr.type do %>
        <% :text -> %>
          <div class="inline-block mt-1">
            <%= Map.get(@media, attr.schema_field) %>
          </div>
        <% :select -> %>
          <div class="inline-block mt-1">
            <div class="chip ~neutral inline-block"><%= Map.get(@media, attr.schema_field) %></div>
          </div>
        <% :multi_select -> %>
          <%= for item <- Map.get(@media, attr.schema_field) do %>
              <div class="chip ~neutral inline-block"><%= item %></div>
          <% end %>
        <% end %>
    </span>
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
