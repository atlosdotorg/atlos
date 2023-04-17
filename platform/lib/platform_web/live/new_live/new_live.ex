defmodule PlatformWeb.NewLive do
  use PlatformWeb, :live_view

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
    <div class="space-y-8 max-w-xl md:mx-auto mx-4 mb-64">
      <h1 class="page-header">New Incident</h1>
      <.card>
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
