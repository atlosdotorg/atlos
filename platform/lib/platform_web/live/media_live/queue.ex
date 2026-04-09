defmodule PlatformWeb.MediaLive.Queue do
  use PlatformWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    which = Map.get(params, "which", "overview")

    {:noreply,
     socket
     |> assign(:title, gettext("Queue"))
     |> assign(:tab, which)
     |> assign(:query, query_for_which(which))}
  end

  def which_to_title(which) do
    case which do
      "overview" -> gettext("Overview")
      "todo" -> gettext("To Do")
      "in_progress" -> gettext("In Progress")
      "help_needed" -> gettext("Help Needed")
      "review" -> gettext("Ready for Review")
    end
  end

  defp query_for_which(which) do
    case which do
      # "overview" is unused
      "overview" -> %{}
      "todo" -> %{"attr_status" => "To Do"}
      "in_progress" -> %{"attr_status" => "In Progress"}
      "help_needed" -> %{"attr_status" => "Help Needed"}
      "review" -> %{"attr_status" => "Ready for Review"}
    end
  end

  def render(assigns) do
    ~H"""
    <article class="w-full px-4 md:px-8">
      <%= if @tab != "overview" do %>
        <div class="mb-8">
          <h1 class={"text-3xl font-medium heading mb-2 " <> Platform.Material.Attribute.attr_color(:status, which_to_title(@tab))}>
            <.link class="text-gray-400" navigate="/queue"><%= gettext("Queue") %> /</.link>
            <%= which_to_title(@tab) %>
          </h1>
          <.link class="text-button" navigate="/queue/overview">&larr; <%= gettext("Back to overview") %></.link>
        </div>
      <% else %>
        <div class="mb-8">
          <h1 class="text-3xl font-medium heading">
            <%= gettext("Queue") %>
          </h1>
        </div>
      <% end %>
      <%= if @tab != "overview" do %>
        <.live_component
          module={PlatformWeb.MediaLive.PaginatedMediaList}
          id="media-list"
          current_user={@current_user}
          query_params={@query}
        />
      <% else %>
        <.live_component
          module={PlatformWeb.MediaLive.GroupedMediaList}
          id="media-list"
          current_user={@current_user}
        />
      <% end %>
    </article>
    """
  end
end
