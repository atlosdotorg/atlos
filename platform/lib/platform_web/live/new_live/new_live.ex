defmodule PlatformWeb.NewLive do
  use PlatformWeb, :live_view

  alias Platform.Accounts

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:stage, "Basic info") |> assign(:title, "New Incident")}
  end

  def handle_info({:media_created, media}, socket) do
    {:noreply, socket |> assign(:media, media) |> assign(:stage, "Upload media")}
  end

  def handle_info({:version_created, _version}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Successfully added media.")
     |> redirect(to: Routes.media_show_path(socket, :show, socket.assigns.media.slug))}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-xl md:mx-auto mx-4">
      <h1 class="page-header">New Incident</h1>
      <.stepper options={["Basic info", "Upload media"]} active={@stage} />

      <%= if @stage == "Basic info" do %>
        <.card>
          <%= if Accounts.is_admin(@current_user) do %>
            <!-- Inform admins about bulk upload -->
            <div class="rounded-md bg-urge-50 p-4 mb-4">
              <div class="flex">
                <div class="flex-shrink-0">
                  <!-- Heroicon name: solid/information-circle -->
                  <svg
                    class="h-5 w-5 text-urge-400"
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                    aria-hidden="true"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </div>
                <div class="ml-3 flex-1 md:flex md:justify-between">
                  <p class="text-sm text-urge-700">
                    As an admin, you can also upload incidents in bulk.
                  </p>
                  <p class="mt-3 text-sm md:mt-0 md:ml-6">
                    <a
                      href="/adminland/upload"
                      class="whitespace-nowrap font-medium text-urge-700 hover:text-urge-600"
                    >
                      Bulk upload <span aria-hidden="true">&rarr;</span>
                    </a>
                  </p>
                </div>
              </div>
            </div>
          <% end %>
          <.live_component
            module={PlatformWeb.NewLive.BasicInfoLive}
            id="basic-info"
            current_user={@current_user}
          />
        </.card>
      <% end %>

      <%= if @stage == "Upload media" do %>
        <.card>
          <:header>
            <h3 class="sec-head">
              <%= @media.description %>
              <%= if @media.attr_sensitive do %>
                <span class="text-neutral-500">
                  (Sensitivity: <%= Enum.join(@media.attr_sensitive, ", ") %>)
                </span>
              <% end %>
            </h3>
            <p class="sec-subhead">
              You can upload additional media later. This media will be assigned the Atlos identifier <%= @media.slug %>.
            </p>
          </:header>
          <.live_component
            module={PlatformWeb.MediaLive.CreateMediaVersion}
            id="upload-version"
            current_user={@current_user}
            media={@media}
          />
        </.card>
      <% end %>
    </div>
    """
  end
end
