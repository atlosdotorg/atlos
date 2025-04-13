defmodule PlatformWeb.ProjectsLive.ExportComponent do
  use PlatformWeb, :live_component
  alias Platform.Projects
  alias Platform.Permissions

  def handle_event("export_csv", %{"project-id" => project_id}, socket) do
    params = %{project_id: project_id}

    PlatformWeb.ExportController.schedule_csv_export(
      socket.assigns.current_user,
      %{"params" => params}
    )

    {:noreply,
     socket
     |> put_flash(
       :info,
       "Your export is being prepared. It should be ready in under 10 minutes. You'll get a notification and an email when it's ready."
     )}
  end

  def handle_event("export_full_project", %{"project-id" => project_id}, socket) do
    project = Projects.get_project!(project_id)

    if Permissions.can_export_full?(socket.assigns.current_user, project) do
      params = %{project_id: project_id}
      PlatformWeb.ExportController.schedule_full_export(socket.assigns.current_user, params)

      {:noreply,
       socket
       |> put_flash(
         :info,
         "Your project export is being prepared. It should be ready in under 10 minutes. You'll get a notification and an email when it's ready."
       )}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Only project managers and owners can export full data.")}
    end
  end

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
                <button
                  type="button"
                  phx-click="export_csv"
                  phx-value-project-id={@project.id}
                  phx-target={@myself}
                  class="button ~urge @high"
                  role="menuitem"
                >
                  <Heroicons.table_cells mini class="-ml-0.5 mr-2 h-5 w-5 opacity-75" />
                  Spreadsheet (CSV)
                </button>
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
                <button
                  type="button"
                  phx-click="export_full_project"
                  phx-value-project-id={@project.id}
                  phx-target={@myself}
                  class="button ~urge @high"
                  role="menuitem"
                >
                  <Heroicons.folder_arrow_down mini class="-ml-0.5 mr-2 h-5 w-5 opacity-75" />
                  All Data and Media (ZIP)
                </button>
              </div>
            </div>
          </div>
        </.card>
      </div>
    </section>
    """
  end
end
