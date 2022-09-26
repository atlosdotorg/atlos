defmodule PlatformWeb.MediaLive.Queue do
  use PlatformWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    which = Map.get(params, "which", "overview")

    {:noreply,
     socket
     |> assign(:title, "Queue")
     |> assign(:full_width, which == "overview")
     |> assign(:tab, which)
     |> assign(:query, query_for_which(which))}
  end

  def which_to_title(which) do
    case which do
      "overview" -> "Overview"
      "unclaimed" -> "Unclaimed"
      "claimed" -> "Claimed"
      "help_needed" -> "Help Needed"
      "review" -> "Ready for Review"
      "needs_upload" -> "Needs Media Upload"
    end
  end

  defp query_for_which(which) do
    case which do
      # "overview" is unused
      "overview" -> %{}
      "unclaimed" -> %{"attr_status" => "Unclaimed"}
      "claimed" -> %{"attr_status" => "Claimed"}
      "help_needed" -> %{"attr_status" => "Help Needed"}
      "review" -> %{"attr_status" => "Ready for Review"}
      "needs_upload" -> %{"no_media_versions" => true}
    end
  end

  def render(assigns) do
    ~H"""
    <article class={"w-full max-w-screen-2xl 2xl:mx-auto ml-4 md:ml-8" <> (if @tab != "overview", do: " mr-4 md:mr-8", else: "")}>
      <%= if @tab != "overview" do %>
        <div class="mb-8">
          <h1 class={"text-3xl font-medium heading mb-2 " <> Platform.Material.Attribute.attr_color(:status, which_to_title(@tab))}>
            <.link class="text-gray-400" navigate="/queue">Queue /</.link>
             <%= which_to_title(@tab) %>
          </h1>
          <.link class="text-button" navigate="/queue/overview">&larr; Back to overview</.link>
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
