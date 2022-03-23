defmodule PlatformWeb.NewLive do
  use PlatformWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:stage, "Basic info")}
  end

  def handle_info({:media_created, media}, socket) do
    IO.inspect media
    {:noreply, socket |> assign(:media, media) |> assign(:stage, "Upload media")}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <h1 class="page-header">Upload New Media</h1>
      <.stepper options={["Basic info", "Upload media", "Additional details"]} active={@stage} />

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
          <h3 class="sec-head">Upload media for: <span class="text-gray-600"><%= @media.description %></span></h3>
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
