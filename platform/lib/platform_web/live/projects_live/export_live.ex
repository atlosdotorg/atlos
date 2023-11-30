defmodule PlatformWeb.ProjectsLive.ExportComponent do
  use PlatformWeb, :live_component

  alias Platform.Permissions

  def render(assigns) do
    ~H"""
    <section class="flex flex-col md:flex-row my-8">
      <div class="mb-4 md:w-[20rem] md:min-w-[20rem] md:mr-20">
        <p class="sec-head text-xl">Export</p>
        <p class="sec-subhead">Export Project Metadata or Media</p>
      </div>
      <div class="grow">
        <div class="rounded-md bg-blue-50 p-4 border-blue-600 border mb-8">
          <div class="flex">
            <div class="flex-shrink-0">
              <Heroicons.information_circle mini class="h-5 w-5 text-blue-500" />
            </div>
            <div class="ml-3 flex-1 md:flex flex-col text-sm text-blue-700 md:justify-between prose prose-sm">
              <p class="text-sm text-blue-700">
                A full export may take a long time to complete.
              </p>
              <details class="-mt-2">
                <summary class="text-sm text-blue-700 cursor-pointer">
                  Learn more about the structure of the ZIP file
                </summary>
                <div class="mt-2 text-sm text-blue-700">
                  <p>
                    The operation will create a zip file containing a folder for each media within the project.
                    Each media folder will contain a metadata.json file with the media metadata,
                    an updates.json file with the media updates, and a folder for each version of the media.
                    In the version folder, there will be a metadata.json file with the version metadata,
                    and a file for each artifact of the version.
                  </p>
                </div>
              </details>
            </div>
          </div>
        </div>
        <.card class="grow border">
          <div class="mb-2">
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

          <div class="mt-8 mb-2">
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
        </.card>
      </div>
    </section>
    """
  end
end
