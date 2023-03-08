defmodule PlatformWeb.NewLive do
  use PlatformWeb, :live_view

  alias Platform.Accounts
  alias Platform.Permissions

  def mount(params, _session, socket) do
    if Permissions.can_create_media?(socket.assigns.current_user) do
      {:ok,
       socket
       |> assign(:title, "New Incident")
       |> assign(:project_id, Map.get(params, "project_id"))}
    else
      {:ok,
       socket
       |> redirect(to: "/")
       |> put_flash(:info, "You cannot create incidents at this time.")}
    end
  end

  def handle_info({:media_created, media}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Incident created successfully.")
     |> redirect(to: "/incidents/#{media.slug}")}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-xl md:mx-auto mx-4">
      <h1 class="page-header">New Incident</h1>
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
          project_id={@project_id}
        />
      </.card>
    </div>
    """
  end
end
