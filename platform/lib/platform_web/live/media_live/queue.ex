defmodule PlatformWeb.MediaLive.Queue do
  use PlatformWeb, :live_view

  alias Platform.Accounts

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    which = Map.get(params, "which", "unclaimed")

    {:noreply,
     socket
     |> assign(:title, "Queue")
     |> assign(:tab, which)
     |> assign(:query, query_for_which(which))}
  end

  def which_to_title(which) do
    case which do
      "unclaimed" -> "Unclaimed"
      "claimed" -> "Claimed"
      "help_needed" -> "Help Needed"
      "review" -> "Ready for Review"
      "needs_upload" -> "Needs Media Upload"
    end
  end

  defp query_for_which(which) do
    case which do
      "unclaimed" -> %{"attr_status" => "Unclaimed"}
      "claimed" -> %{"attr_status" => "Claimed"}
      "help_needed" -> %{"attr_status" => "Help Needed"}
      "review" -> %{"attr_status" => "Ready for Review"}
      "needs_upload" -> %{"no_media_versions" => true}
    end
  end

  def render(assigns) do
    ~H"""
    <article class="w-full xl:max-w-screen-xl px-4 md:px-8">
      <div>
        <div class="border-b border-gray-200 flex flex-col md:flex-row mb-8 items-baseline">
          <h1 class="text-3xl flex-grow font-medium md:mr-8">Queue</h1>
          <nav class="-mb-px flex space-x-8 overflow-x-auto max-w-full" aria-label="Tabs">
            <% active_classes =
              "flex gap-1 items-center border-urge-500 text-urge-600 whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm" %>
            <% inactive_classes =
              "flex gap-1 items-center border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm" %>
            <%= live_patch(
              class: if(@tab == "unclaimed", do: active_classes, else: inactive_classes),
              to: "/queue/unclaimed"
            ) do %>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4 opacity-75"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z"
                  clip-rule="evenodd"
                />
              </svg>
              Unclaimed
            <% end %>
            <%= live_patch(
              class: if(@tab == "help_needed", do: active_classes, else: inactive_classes),
              to: "/queue/help_needed"
            ) do %>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4 opacity-75"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-2 0c0 .993-.241 1.929-.668 2.754l-1.524-1.525a3.997 3.997 0 00.078-2.183l1.562-1.562C15.802 8.249 16 9.1 16 10zm-5.165 3.913l1.58 1.58A5.98 5.98 0 0110 16a5.976 5.976 0 01-2.516-.552l1.562-1.562a4.006 4.006 0 001.789.027zm-4.677-2.796a4.002 4.002 0 01-.041-2.08l-.08.08-1.53-1.533A5.98 5.98 0 004 10c0 .954.223 1.856.619 2.657l1.54-1.54zm1.088-6.45A5.974 5.974 0 0110 4c.954 0 1.856.223 2.657.619l-1.54 1.54a4.002 4.002 0 00-2.346.033L7.246 4.668zM12 10a2 2 0 11-4 0 2 2 0 014 0z"
                  clip-rule="evenodd"
                />
              </svg>
              Help Needed
            <% end %>
            <%= live_patch(
              class: if(@tab == "needs_upload", do: active_classes, else: inactive_classes),
              to: "/queue/needs_upload"
            ) do %>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-4 w-4 opacity-75"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path d="M4 3a2 2 0 100 4h12a2 2 0 100-4H4z" />
                <path
                  fill-rule="evenodd"
                  d="M3 8h14v7a2 2 0 01-2 2H5a2 2 0 01-2-2V8zm5 3a1 1 0 011-1h2a1 1 0 110 2H9a1 1 0 01-1-1z"
                  clip-rule="evenodd"
                />
              </svg>
              Needs Media Upload
            <% end %>
            <%= if Accounts.is_privileged(@current_user) do %>
              <!-- Regular users can see this page; that's fine. We just don't want to confuse them by putting it in their navbar. -->
              <%= live_patch(
                class: if(@tab == "review", do: active_classes, else: inactive_classes),
                to: "/queue/review"
              ) do %>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4 opacity-75"
                  viewBox="0 0 20 20"
                  fill="currentColor"
                >
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                    clip-rule="evenodd"
                  />
                </svg>
                Ready for Review
              <% end %>
            <% end %>
          </nav>
        </div>
      </div>
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
