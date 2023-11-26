defmodule PlatformWeb.ProjectsLive.ExportComponent do
  use PlatformWeb, :live_component

  alias Platform.Utils
  alias Platform.Material
  alias Platform.Auditor
  alias Platform.Permissions

  def render(assigns) do
    ~H"""
    <section class="flex flex-col md:flex-row gap-4 pt-8">
      <div class="mb-4 md:w-[20rem] md:min-w-[20rem] md:mr-20">
        <p class="sec-head text-xl">Export</p>
        <p class="sec-subhead">Export Project Metadata or Media</p>
      </div>
      <div class="grow">
        <%= button type: "button", to: Routes.export_path(@socket, :create_csv_export, %{"project_id" => @project.id}),
            class: "base-button",
            role: "menuitem",
            method: :post
          do %>
          <Heroicons.archive_box mini class="-ml-0.5 mr-2 h-5 w-5 text-neutral-400" /> Export CSV
        <% end %>

        <%= button type: "button", to: Routes.export_path(@socket, :create_full_export, %{"project_id" => @project.id}),
            class: "base-button",
            role: "menuitem",
            method: :post
          do %>
          <Heroicons.archive_box mini class="-ml-0.5 mr-2 h-5 w-5 text-neutral-400" /> Export Full
        <% end %>
      </div>
    </section>
    """
  end
end
