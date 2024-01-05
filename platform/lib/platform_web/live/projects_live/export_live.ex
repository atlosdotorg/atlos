defmodule PlatformWeb.ProjectsLive.ExportComponent do
  use PlatformWeb, :live_component


  def render(assigns) do
    ~H"""
    <section class="flex flex-col lg:flex-row my-8">
      <div class="mb-4 lg:w-[20rem] lg:min-w-[20rem] lg:mr-20">
        <p class="sec-head text-xl">Export</p>
        <p class="sec-subhead">Export your data to other portable formats.</p>
      </div>
      <div class="grow">
        <div
          :if={feature_available?(:full_export)}
          class="rounded-md bg-blue-50 p-4 border-blue-600 border mb-8"
        >
          <div class="flex">
            <div class="flex-shrink-0">
              <Heroicons.information_circle mini class="h-5 w-5 text-blue-500" />
            </div>
            <div class="ml-3 flex-1 lg:flex flex-col text-sm text-blue-700 lg:justify-between prose prose-sm max-w-full">
              <p class="text-sm text-blue-700">
                Your data on Atlos is fully portable. You can export your project's data to a spreadsheet (CSV), or you can export all of your project's data and media to a zip file.
              </p>
              <details class="-mt-2">
                <summary class="text-sm text-blue-700 cursor-pointer font-medium">
                  Learn more about the structure of Atlos exports
                </summary>
                <div class="mt-2 text-sm text-blue-700">
                  <p>
                    <ul>
                      <li>
                        Spreadsheet (CSV) exports will contain a row for each incident in your project, as well as a link to each piece of attached source material. Files uploaded directly to Atlos are not included in CSV exports.
                      </li>
                      <li>
                        Full exports will create a zip file containing a folder for each incident in the project.
                      </li>
                      <li>
                        Each incident folder will contain a metadata.json file with the incident metadata,
                        an updates.json file with its updates, and a folder for each piece of source material attached to the incident.
                      </li>
                      <li>
                        In the source material folder, there will be a metadata.json file with the version metadata,
                        and a file for each artifact (file) associated with the version.
                      </li>
                    </ul>
                  </p>
                </div>
              </details>
            </div>
          </div>
        </div>
        <.card no_pad={true} class="grow border">
          <div class="divide-y grid grid-cols-1">
            <div class="lg:flex gap-4 justify-between py-4 px-5 sm:py-5">
              <div>
                <p class="sec-head">Export Incidents</p>
                <p class="sec-subhead">Export metadata about all incidents in this project.</p>
              </div>
              <div>
                <%= button type: "button", to: Routes.export_path(@socket, :create_csv_export, %{"project_id" => @project.id}),
              class: "button ~urge @high",
              role: "menuitem",
              method: :post
            do %>
                  <Heroicons.table_cells mini class="-ml-0.5 mr-2 h-5 w-5 opacity-75" />
                  Spreadsheet (CSV)
                <% end %>
              </div>
            </div>

            <div
              :if={feature_available?(:full_export)}
              class="lg:flex gap-4 justify-between py-4 px-5 sm:py-5"
            >
              <div>
                <p class="sec-head">Full Export</p>
                <p class="sec-subhead mb-2">
                  Export all metadata and media in this project.
                  Note that this is an expensive operation and may take a long time to complete.
                </p>
              </div>
              <div>
                <%= button type: "button", to: Routes.export_path(@socket, :create_project_full_export, %{"project_id" => @project.id}),
                  class: "button ~urge @high",
                  role: "menuitem",
                  method: :post
                do %>
                  <Heroicons.folder_arrow_down mini class="-ml-0.5 mr-2 h-5 w-5 opacity-75" />
                  All Data & Media (ZIP)
                <% end %>
              </div>
            </div>
          </div>
        </.card>
      </div>
    </section>
    """
  end
end
