defmodule PlatformWeb.ProjectsLive.ExportComponent do
  use PlatformWeb, :live_component

  alias Platform.Permissions

  def render(assigns) do
    ~H"""
    <section class="flex flex-col md:flex-row gap-4 py-8">
      <div class="mb-4 md:w-[20rem] md:min-w-[20rem] md:mr-20">
        <p class="sec-head text-xl">Export</p>
        <p class="sec-subhead">Export Project Metadata or Media</p>
      </div>
      <div class="grow">
        <div class="mt-4 mb-2">
          <p class="sec-head">Export Incidents</p>
          <p class="sec-subhead mb-2">Export metadata about all incidents in this project.</p>
          <%= button type: "button", to: Routes.export_path(@socket, :create_csv_export, %{"project_id" => @project.id}),
            class: "base-button",
            role: "menuitem",
            method: :post
          do %>
            <Heroicons.document_arrow_down mini class="-ml-0.5 mr-2 h-5 w-5 text-neutral-400" />
            Incidents (CSV)
          <% end %>
        </div>

        <%= if Permissions.can_export_full?(@current_user, @project) do %>
          <div class="mt-4 mb-2">
            <p class="sec-head">Full Export</p>
            <p class="sec-subhead mb-2">
              Export all metadata and media in this project.
              Note that this is an expensive operation and may take a long time to complete.
            </p>
            <%= button type: "button", to: Routes.export_path(@socket, :create_project_full_export, %{"project_id" => @project.id}),
              class: "base-button",
              role: "menuitem",
              method: :post
            do %>
              <Heroicons.folder_arrow_down mini class="-ml-0.5 mr-2 h-5 w-5 text-neutral-400" />
              All Data & Media (ZIP)
            <% end %>
          </div>
        <% end %>
      </div>
    </section>
    """
  end
end
