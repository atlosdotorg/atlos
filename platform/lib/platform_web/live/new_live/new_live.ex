defmodule PlatformWeb.NewLive do
  use PlatformWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:stage, "Basic info")}
  end

  def handle_info({:media_created, media}, socket) do
    {:noreply, socket |> assign(:media, media) |> assign(:stage, "Upload media")}
  end

  def handle_info({:version_created, _version}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Successfully uploaded media.")
     |> redirect(to: Routes.media_show_path(socket, :show, socket.assigns.media.slug))}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8 max-w-xl">
      <h1 class="page-header">Upload New Media</h1>
      <.stepper options={["Basic info", "Upload media"]} active={@stage} />

      <%= if @stage == "Basic info" do %>
      <.card>
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
            <span class="text-neutral-500">(Sensitivity: <%= Enum.join(@media.attr_sensitive, ", ") %>)</span>
            <% end %>
          </h3>
          <p class="sec-subhead">This media will be assigned the Atlos identifier <%= @media.slug %>.</p>
        </:header>
        <.live_component
          module={PlatformWeb.MediaLive.UploadVersionLive}
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
