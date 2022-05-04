defmodule PlatformWeb.MediaLive.CreateMediaVersion do
  use PlatformWeb, :live_component

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign(:tab, :direct)}
  end

  def handle_event("set_tab", %{"tab" => tab}, socket) do
    val =
      case tab do
        "direct" -> :direct
        "upload" -> :upload
      end

    {:noreply, socket |> assign(:tab, val)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <nav
        class="relative border rounded overflow-hidden z-0 rounded-lg shadow flex divide-x divide-gray-200"
        aria-label="Tabs"
      >
        <button
          type="button"
          phx-click="set_tab"
          phx-value-tab="direct"
          phx-target={@myself}
          class="group relative min-w-0 flex-1 overflow-hidden bg-white py-4 px-4 text-sm font-medium text-center hover:bg-gray-50 focus:z-10"
          aria-current="page"
        >
          <span>Link to Media</span>
          <%= if @tab == :direct do %>
            <span aria-hidden="true" class="bg-urge-500 absolute inset-x-0 bottom-0 h-0.5"></span>
          <% else %>
            <span aria-hidden="true" class="bg-transparent absolute inset-x-0 bottom-0 h-0.5"></span>
          <% end %>
        </button>

        <button
          type="button"
          phx-click="set_tab"
          phx-value-tab="upload"
          phx-target={@myself}
          class="group relative min-w-0 flex-1 overflow-hidden bg-white py-4 px-4 text-sm font-medium text-center hover:bg-gray-50 focus:z-10"
        >
          <span>Manual Upload</span>
          <%= if @tab == :upload do %>
            <span aria-hidden="true" class="bg-urge-500 absolute inset-x-0 bottom-0 h-0.5"></span>
          <% else %>
            <span aria-hidden="true" class="bg-transparent absolute inset-x-0 bottom-0 h-0.5"></span>
          <% end %>
        </button>
      </nav>
      <section class="mt-8">
        <%= if @tab == :direct do %>
          <.live_component
            module={PlatformWeb.MediaLive.LinkVersionLive}
            id="link-version"
            current_user={@current_user}
            media={@media}
          />
        <% else %>
          <.live_component
            module={PlatformWeb.MediaLive.UploadVersionLive}
            id="upload-version"
            current_user={@current_user}
            media={@media}
          />
        <% end %>
      </section>
    </div>
    """
  end
end
