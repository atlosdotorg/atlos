defmodule PlatformWeb.ProjectsLive.BulkUploadLive do
  use PlatformWeb, :live_component

  alias Platform.Utils
  alias Platform.Material
  alias Platform.Auditor
  alias Platform.Permissions

  def update(
        %{project: project, current_user: current_user} = _assigns,
        socket
      ) do
    unless Permissions.can_bulk_upload_media_to_project?(current_user, project) do
      raise gettext("No permission")
    end

    Temp.track!()

    {:ok,
     socket
     |> assign(:project, project)
     |> assign(:stage, "upload_incidents")
     |> assign(:current_user, current_user)
     |> assign(:processing, false)
     |> assign(:media_processing_error, false)
     |> assign(:decoding_errors, [])
     |> assign(:changesets, [])
     |> assign(:uploaded_files, [])
     |> allow_upload(:bulk_upload,
       accept: ~w(.csv),
       max_entries: 1,
       max_file_size: 250_000_000,
       auto_upload: true,
       progress: &handle_progress/3,
       chunk_size: 512_000
     )}
  end

  defp friendly_error(:too_large),
    do: gettext("This file is too large; the maximum size is 250 megabytes.")

  defp friendly_error(:not_accepted),
    do: gettext("The file type you are uploading is not supported. We only support CSV uploads.")

  defp handle_progress(:bulk_upload, entry, socket) do
    if entry.done? do
      {:noreply, socket |> handle_uploaded_file(entry)}
    else
      {:noreply, socket}
    end
  end

  defp handle_static_file(%{path: path}) do
    # Just make a copy of the file; all the real processing is done later in handle_uploaded_file.
    to_path = Temp.path!()
    File.cp!(path, to_path)
    {:ok, to_path}
  end

  defp handle_uploaded_file(socket, entry) do
    path = consume_uploaded_entry(socket, entry, &handle_static_file(&1))

    data = File.read!(path)

    # If data begins with \uFEFF, remove it.
    data =
      case String.split(data, "\uFEFF") do
        [_, rest] -> rest
        _ -> data
      end

    {:ok, stream} =
      data
      |> StringIO.open()

    rows =
      stream
      |> IO.binstream(4)
      |> CSV.decode(headers: true, unescape_formulas: true)
      |> Enum.to_list()

    decoding_errors =
      Enum.filter(rows, fn {k, _v} ->
        k == :error
      end)
      |> Enum.map(fn {_k, v} -> v end)

    if length(decoding_errors) > 0 do
      socket
      |> assign(
        :decoding_errors,
        decoding_errors
      )
    else
      changesets =
        rows
        |> Enum.with_index(1)
        |> Enum.map(fn {{:ok, item}, idx} ->
          {Material.bulk_import_change(item, socket.assigns.project), idx}
        end)

      socket
      |> assign(:stage, "confirm_information")
      |> assign(:upload_path, path)
      |> assign(:changesets, changesets)
      |> assign(:import_items, rows |> Enum.map(fn {:ok, item} -> item end))
    end
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("reset", _params, socket) do
    {:ok, s} = update(socket.assigns, socket)
    {:noreply, s}
  end

  def handle_event("save", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("publish", _params, socket) do
    unless Permissions.can_bulk_upload_media_to_project?(
             socket.assigns.current_user,
             socket.assigns.project
           ) do
      raise gettext("No permission")
    end

    Task.start(fn ->
      Auditor.log(
        :bulk_upload,
        %{num_items: length(socket.assigns.import_items)},
        socket
      )

      socket.assigns.import_items
      |> Enum.map(fn item ->
        {:ok, _} = item |> Material.bulk_import_create(socket.assigns.project)
      end)
    end)

    {:noreply, socket |> assign(:stage, "next_steps")}
  end

  defp extract_errors(changeset, project) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {key, value} ->
      case key do
        :project_attributes ->
          Enum.map(Enum.with_index(value), fn {errors, idx} ->
            attr_idx =
              Ecto.Changeset.get_field(
                changeset.changes[:project_attributes] |> Enum.at(idx),
                :id
              )

            attr = Platform.Material.Attribute.get_attribute(attr_idx, project: project)
            {attr.label, Map.values(errors)}
          end)

        :attr_geolocation ->
          # We want a custom error message for geolocation; see https://github.com/atlosdotorg/atlos/issues/976
          {key,
           [
             gettext("Unable to parse this location; please enter geolocation in separate \"latitude\" and \"longitude\" columns.")
           ]}

        _ ->
          {key, value}
      end
    end)
    |> List.flatten()
    |> Enum.filter(fn {_, errors} -> length(errors) > 0 end)
    |> Enum.into(%{})
  end

  def render(assigns) do
    active_uploads = Enum.filter(assigns.uploads.bulk_upload.entries, &(!&1.cancelled?))

    assigns =
      assigns
      |> assign(
        :active_uploads,
        active_uploads
      )

    assigns =
      assigns
      |> assign(
        :is_uploading,
        not Enum.empty?(active_uploads)
      )
      |> assign(
        :is_invalid,
        Enum.any?(assigns.uploads.bulk_upload.entries, &(!&1.valid?)) or
          assigns.media_processing_error
      )
      |> assign(:is_complete, Enum.any?(active_uploads, & &1.done?))
      |> assign(
        :cancel_upload,
        if not Enum.empty?(active_uploads) do
          ~H"""
          <button
            phx-click="cancel_upload"
            phx-target={@myself}
            phx-value-ref={hd(@active_uploads).ref}
            class="text-sm label ~neutral"
            type="button"
          >
            <%= gettext("Cancel Upload") %>
          </button>
          """
        end
      )

    ~H"""
    <section class="flex flex-col lg:flex-row mt-8 mb-32">
      <div class="mb-4 lg:w-[20rem] lg:min-w-[20rem] lg:mr-20">
        <p class="sec-head text-xl"><%= gettext("Bulk Import") %></p>
        <p class="sec-subhead"><%= gettext("Upload many incidents from a CSV file.") %></p>
      </div>
      <div class="grow">
        <div class="rounded-md bg-blue-50 p-4 border-blue-600 border mb-8">
          <div class="flex">
            <div class="flex-shrink-0">
              <Heroicons.information_circle mini class="h-5 w-5 text-blue-500" />
            </div>
            <div class="ml-3 flex-1 lg:flex flex-col text-sm text-blue-700 lg:justify-between prose prose-sm">
              <p>
                <%= gettext("Atlos requires a very specific format for bulk uploads.") %>
              </p>
              <details class="-mt-2">
                <summary class="cursor-pointer font-medium">
                  <%= gettext("Learn about the required file format") %>
                </summary>
                <p>
                  <%= gettext("Atlos can perform bulk imports from CSV files into this project with the following columns:") %>
                </p>
                <p class="font-medium"><%= gettext("Required") %></p>
                <ul>
                  <%= for attr <- Material.Attribute.active_attributes(project: @project) |> Enum.filter(& &1.required) do %>
                    <li>
                      <.attr_import_format_explanation name={attr.name} project={@project} />
                    </li>
                  <% end %>
                </ul>
                <p class="font-medium"><%= gettext("Optional") %></p>
                <ul>
                  <%= for attr <- Material.Attribute.active_attributes(project: @project) |> Enum.reject(& &1.required) do %>
                    <li>
                      <.attr_import_format_explanation name={attr.name} project={@project} />
                    </li>
                  <% end %>
                  <li>
                    <span class="font-medium"><%= gettext("sources") %></span>
                    &mdash; <%= gettext("include sources as URLs in columns named %{source_1}, %{source_2}, %{source_3}, etc.", source_1: "<span class=\"badge ~urge\">source_1</span>", source_2: "<span class=\"badge ~urge\">source_2</span>", source_3: "<span class=\"badge ~urge\">source_3</span>") |> raw() %>
                  </li>
                </ul>
                <p><%= gettext("Note that this format perfectly matches Atlos' bulk exports.") %></p>
              </details>
            </div>
          </div>
        </div>
        <.card class="grow border">
          <.stepper
            options={[
              {"upload_incidents", gettext("Upload incidents")},
              {"confirm_information", gettext("Confirm information")},
              {"next_steps", gettext("Next steps")}
            ]}
            active={@stage}
          />
          <hr class="sep" />
          <%= case @stage do %>
            <% "upload_incidents" -> %>
              <form phx-change="validate" phx-submit="save" phx-target={@myself} id="upload-form">
                <%= if length(@decoding_errors) > 0 do %>
                  <aside class="aside ~critical mb-8">
                    <p>
                      <strong><%= gettext("We encountered errors while processing your upload.") %></strong>
                      <%= gettext("Please correct the errors below and re-upload your CSV.") %>
                    </p>
                    <ol class="list-decimal mt-4 ml-8">
                      <%= for error <- @decoding_errors do %>
                        <li><%= error %></li>
                      <% end %>
                    </ol>
                  </aside>
                <% end %>
                <div
                  class="w-full flex justify-center items-center px-6 pt-5 pb-6 border-2 h-40 border-gray-300 border-dashed rounded-md"
                  phx-drop-target={@uploads.bulk_upload.ref}
                  phx-target={@myself}
                >
                  <.live_file_input upload={@uploads.bulk_upload} class="sr-only" />
                  <%= if @processing do %>
                    <div>
                      <div class="space-y-1 text-center">
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          class="mx-auto h-12 w-12 text-urge-400 animate-spin"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                          stroke-width="2"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
                          />
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                          />
                        </svg>
                        <div class="w-full text-sm text-gray-600">
                          <div class="w-42 mt-2 text-center">
                            <p class="font-medium text-neutral-800 mb-1"><%= gettext("Processing your upload...") %></p>
                            <p>
                              <%= gettext("This might take a moment. Please keep the window open.") %>
                            </p>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% else %>
                    <%= cond do %>
                      <% @is_complete -> %>
                        <div class="space-y-1 text-center phx-only-during-reg">
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            class="mx-auto h-12 w-12 text-positive-600"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                            stroke-width="2"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                            />
                          </svg>
                          <div class="w-full text-sm text-gray-600">
                            <%= for entry <- @uploads.bulk_upload.entries do %>
                              <div class="w-42 mt-4 text-center">
                                <p><%= gettext("Uploaded %{filename}.", filename: Utils.truncate(entry.client_name)) %></p>
                              </div>
                            <% end %>
                          </div>
                          <div>
                            <%= @cancel_upload %>
                          </div>
                        </div>
                      <% @is_invalid -> %>
                        <div class="space-y-1 text-center phx-only-during-reg">
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            class="mx-auto h-12 w-12 text-critical-600"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                            stroke-width="2"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                            />
                          </svg>
                          <div class="w-full text-sm text-gray-600">
                            <p><%= gettext("Something went wrong while processing your upload.") %></p>
                            <%= for entry <- @uploads.bulk_upload.entries do %>
                              <%= for err <- upload_errors(@uploads.bulk_upload, entry) do %>
                                <p class="my-2"><%= friendly_error(err) %></p>
                              <% end %>
                            <% end %>
                            <label
                              for={@uploads.bulk_upload.ref}
                              class="relative cursor-pointer bg-white rounded-md font-medium !text-urge-600 hover:text-urge-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-urge-500"
                            >
                              <span><%= gettext("Upload another file") %></span>
                            </label>
                          </div>
                        </div>
                      <% @is_uploading -> %>
                        <div class="space-y-1 text-center w-full phx-only-during-reg">
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            aria-hidden="true"
                            class="mx-auto h-12 w-12 text-gray-400 animate-pulse"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                            stroke-width="2"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"
                            />
                          </svg>
                          <div class="w-full text-sm text-gray-600">
                            <%= for entry <- @uploads.bulk_upload.entries do %>
                              <%= if entry.progress < 100 and entry.progress > 0 do %>
                                <div class="w-42 mt-4 text-center">
                                  <p><%= gettext("Uploading %{filename}", filename: Utils.truncate(entry.client_name)) %></p>
                                  <progress
                                    value={entry.progress}
                                    max="100"
                                    class="progress ~urge mt-2"
                                  >
                                    <%= entry.progress %>%
                                  </progress>
                                </div>
                              <% end %>
                            <% end %>
                          </div>
                          <div>
                            <%= @cancel_upload %>
                          </div>
                        </div>
                      <% true -> %>
                        <div class="space-y-1 text-center phx-only-during-reg">
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            aria-hidden="true"
                            class="mx-auto h-12 w-12 text-gray-400"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                            stroke-width="2"
                          >
                            <path
                              stroke-linecap="round"
                              stroke-linejoin="round"
                              d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"
                            />
                          </svg>
                          <div class="flex text-sm text-gray-600 justify-center">
                            <label
                              for={@uploads.bulk_upload.ref}
                              class="relative cursor-pointer bg-white rounded-md font-medium !text-urge-600 hover:text-urge-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-urge-500"
                            >
                              <span><%= gettext("Upload a file") %></span>
                            </label>
                            <p class="pl-1 text-center"><%= gettext("or drag and drop") %></p>
                          </div>
                          <p class="text-xs text-gray-500"><%= gettext("CSV up to 250MB") %></p>
                        </div>
                    <% end %>
                  <% end %>
                </div>
              </form>
            <% "confirm_information" -> %>
              <% invalid = Enum.filter(@changesets, fn {x, _idx} -> not x.valid? end) %>
              <%= if length(invalid) > 0 do %>
                <div class="rounded-md bg-critical-50 p-4 border-critical-600 border mb-8">
                  <div class="flex">
                    <div class="flex-shrink-0">
                      <Heroicons.exclamation_circle mini class="h-5 w-5 text-critical-500" />
                    </div>
                    <div class="ml-3 flex-1 lg:flex flex-col text-sm text-critical-700 lg:justify-between prose prose-sm max-w-full">
                      <p>
                        <%= gettext("There were errors processing your upload. Please review the errors and try again.") %>
                      </p>
                      <div>
                        <div class="flex flex-col divide-y">
                          <%= for {changeset, idx} <- invalid do %>
                            <article class="py-2 border-t border-t-critical-300 flex flex-col lg:flex-row">
                              <strong class="font-semibold text-critical-600 lg:w-1/6 mt-2">
                                <%= gettext("Row %{idx}", idx: idx) %>
                              </strong>
                              <div class="-mt-2">
                                <%= for {key, errors} <- extract_errors(changeset, @project) |> Map.to_list() do %>
                                  <p>
                                    <% label = to_string(key) %>
                                    <span class="badge ~critical">
                                      <%= if String.starts_with?(label, "attr_"),
                                        do: String.slice(label, 5..String.length(label)),
                                        else: label %>
                                    </span>
                                    <%= Enum.join(
                                      errors,
                                      ","
                                    ) %>
                                  </p>
                                <% end %>
                              </div>
                            </article>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
                <button
                  type="button"
                  phx-click="reset"
                  phx-target={@myself}
                  class="button ~urge mt-4 @high"
                  )
                >
                  <%= gettext("New Upload") %>
                </button>
              <% else %>
                <% valid = Enum.filter(@changesets, fn {x, _idx} -> x.valid? end) %>
                <aside class="bg-positive-100 rounded-lg border border-positive-600 text-positive-700 text-sm p-4 -mt-4">
                  <p>
                    <strong class="font-medium text-positive-800">
                      <%= ngettext("Found %{count} incident.", "Found %{count} incidents.", length(@changesets)) %>
                    </strong>
                    <%= gettext("If everything below looks right, click \"Publish\" to publish these incidents to Atlos. Note that media will be archived on a best-effort basis.") %>
                    <span :if={Enum.count(valid) > 50}>
                      <%= gettext("We have truncated the list to the first 50 incidents.") %>
                    </span>
                  </p>
                </aside>
                <div class="grid gap-4 grid-cols-1 mt-4">
                  <%= for {changeset, idx} <- Enum.slice(valid, 0..50) do %>
                    <div class="rounded-lg border">
                      <p class="sec-head text-md p-4 border-b text-sm">
                        <span class="text-gray-500"><%= gettext("Row %{idx}:", idx: idx) %></span> <%= Ecto.Changeset.get_field(
                          changeset,
                          :attr_description
                        ) %>
                      </p>
                      <div class="grid gap-4 grid-cols-1 lg:grid-cols-3 text-sm p-4">
                        <% applied_media =
                          Ecto.Changeset.apply_changes(changeset) %>
                        <%= for attr <- Material.Attribute.active_attributes(project: @project) do %>
                          <% value = Material.get_attribute_value(applied_media, attr) %>
                          <%= if not is_nil(value) and value != [] and value != "" and attr.schema_field != :attr_description do %>
                            <div class="overflow-hidden max-w-full">
                              <p class="text-gray-600 font-medium mb-1">
                                <%= Material.Attribute.standardized_label(attr, project: @project) %>
                              </p>
                              <div>
                                <.attr_entry
                                  name={attr.name}
                                  value={value}
                                  project={@project}
                                  current_user={@current_user}
                                  media={applied_media}
                                  membership={:ignore}
                                />
                              </div>
                            </div>
                          <% end %>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
                <button
                  type="button"
                  phx-click="reset"
                  phx-target={@myself}
                  class="base-button mt-4"
                  )
                >
                  <%= gettext("Back") %>
                </button>
                <button
                  type="button"
                  class="button ~urge @high mt-4"
                  phx-target={@myself}
                  phx-click="publish"
                >
                  <%= gettext("Publish to Atlos") %>
                </button>
              <% end %>
            <% "next_steps" -> %>
              <aside class="bg-positive-100 rounded-lg border border-positive-600 text-positive-700 text-sm p-4 -mt-4">
                <p>
                  <strong class="font-medium text-positive-800"><%= gettext("Your import has begun!") %></strong>
                  <%= gettext("It will continue in the background. You can safely close this tab.") %>
                </p>
              </aside>
              <button
                type="button"
                phx-click="reset"
                phx-target={@myself}
                class="button ~urge @high mt-4"
                )
              >
                <%= gettext("New Import") %>
              </button>
          <% end %>
        </.card>
      </div>
    </section>
    """
  end
end
