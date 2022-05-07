defmodule PlatformWeb.MediaLive.Queue do
  use PlatformWeb, :live_view
  alias Platform.Material

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"which" => which} = params, _uri, socket) do
    {:noreply,
      socket
      |> assign(:title, "Queue")
      |> assign(:query, query_for_which(which))}
  end

  defp query_for_which(which) do
    case which do
      "help_needed" -> %{"attr_flag" => "Help Needed"}
    end
  end

  def render(assigns) do
    ~H"""
    <article class="w-full max-w-screen-xl px-8">
      <section class="flex w-full flex-wrap md:flex-nowrap gap-4 mb-8 items-center mb-8 border-b pb-4">
        <h1 class="header text-3xl flex-grow font-medium md:mr-8">Queue</h1>
        <div class="lg:w-[40em] flex flex-col md:flex-row gap-2">
          ...
        </div>
      </section>
      <.live_component
        module={PlatformWeb.MediaLive.PaginatedMediaList}
        id="media-list"
        current_user={@current_user}
        query_params={@query}
      />
    </article>
    """
  end
end
