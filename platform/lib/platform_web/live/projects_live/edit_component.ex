defmodule PlatformWeb.ProjectsLive.EditComponent do
  use PlatformWeb, :live_component

  alias Platform.Projects.ProjectAttribute
  alias Platform.Auditor
  alias Platform.Projects
  alias Platform.Permissions

  def update(assigns, socket) do
    assigns = Map.put_new(assigns, :project, %Projects.Project{})

    if not is_nil(assigns.project) and
         not Permissions.can_edit_project_metadata?(assigns.current_user, assigns.project) and
         not Permissions.can_change_project_active_status?(assigns.current_user, assigns.project) do
      raise PlatformWeb.Errors.Unauthorized, "You do not have permission to edit this project"
    end

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:project, fn -> %Projects.Project{} end)

    {:ok,
     socket
     |> assign(:actively_editing_id, nil)
     |> assign_new(:general_changeset, fn ->
       Projects.change_project(socket.assigns.project)
     end)
     |> assign_new(:custom_attribute_changeset, fn ->
       Projects.change_project(socket.assigns.project)
     end)
     |> assign_new(:show_panes, fn -> [:general, :custom_attributes] end)}
  end

  def assign_general_changeset(socket, attrs \\ %{}) do
    socket
    |> assign(
      :general_changeset,
      Projects.change_project(socket.assigns.project, attrs) |> Map.put(:action, :validate)
    )
  end

  def assign_custom_attribute_changeset(socket, attrs \\ %{}) do
    socket
    |> assign(
      :custom_attribute_changeset,
      Projects.change_project(socket.assigns.project, attrs) |> Map.put(:action, :validate)
    )
  end

  def handle_event("close", _params, socket) do
    send(self(), {:close, nil})
    {:noreply, socket}
  end

  def handle_event("toggle_active", _params, socket) do
    if Permissions.can_change_project_active_status?(
         socket.assigns.current_user,
         socket.assigns.project
       ) do
      {:ok, project} =
        Projects.update_project_active(
          socket.assigns.project,
          not socket.assigns.project.active,
          socket.assigns.current_user
        )

      Auditor.log(
        :project_active_status_changed,
        %{project: socket.assigns.project, new_status: not socket.assigns.project.active},
        socket
      )

      send(self(), {:project_saved, project})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("validate_general", %{"project" => project_params}, socket) do
    {:noreply, socket |> assign_general_changeset(project_params) |> Map.put(:action, :validate)}
  end

  def handle_event("validate_custom_attributes", %{"project" => project_params}, socket) do
    {:noreply,
     socket |> assign_custom_attribute_changeset(project_params) |> Map.put(:action, :validate)}
  end

  def handle_event("save_general", %{"project" => project_params}, socket) do
    case socket.assigns.project.id do
      nil ->
        case Projects.create_project(project_params, socket.assigns.current_user) do
          {:ok, project} ->
            send(self(), {:close, project})
            {:noreply, socket |> assign(project: project)}

          {:error, changeset} ->
            {:noreply,
             socket |> assign(:general_changeset, changeset |> Map.put(:action, :validate))}
        end

      _project_id ->
        case Projects.update_project(
               socket.assigns.project,
               project_params,
               socket.assigns.current_user
             ) do
          {:ok, project} ->
            send(self(), {:project_saved, project})
            {:noreply, socket |> assign(project: project) |> assign(:actively_editing_id, nil)}

          {:error, changeset} ->
            {:noreply,
             socket |> assign(:general_changeset, changeset |> Map.put(:action, :validate))}
        end
    end
  end

  def handle_event("save_custom_attributes", %{"project" => project_params}, socket) do
    # Can only do when project already exists
    case Projects.update_project(
           socket.assigns.project,
           project_params,
           socket.assigns.current_user
         ) do
      {:ok, project} ->
        send(self(), {:project_saved, project})

        {:noreply,
         socket
         |> assign(project: project)
         |> assign(:actively_editing_id, nil)
         |> assign_custom_attribute_changeset()}

      {:error, changeset} ->
        {:noreply,
         socket |> assign(:custom_attributes_changeset, changeset |> Map.put(:action, :validate))}
    end
  end

  def handle_event("add_attr", _, socket) do
    socket =
      update(socket, :custom_attribute_changeset, fn changeset ->
        existing = Ecto.Changeset.get_field(changeset, :attributes, [])

        Ecto.Changeset.put_embed(
          changeset,
          :attributes,
          existing ++ [%ProjectAttribute{}]
        )
      end)
      |> assign(:actively_editing_id, :new)

    {:noreply, socket}
  end

  def handle_event("delete_attr", %{"id" => id}, socket) do
    # Delete the custom attribute, save, and close the actively editing modal
    {:ok, project} =
      Projects.delete_project_attribute(socket.assigns.project, id, socket.assigns.current_user)

    send(self(), {:project_saved, project})

    {:noreply,
     socket
     |> assign(:project, project)
     |> assign(:actively_editing_id, nil)
     |> assign_custom_attribute_changeset()}
  end

  def handle_event("open_modal", %{"id" => id}, socket) do
    {:noreply, socket |> assign(:actively_editing_id, id)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> assign(:actively_editing_id, nil) |> assign_custom_attribute_changeset()}
  end

  def type_mapping,
    do: [
      "Single Select": :select,
      "Multiple Select": :multi_select,
      Text: :text,
      Date: :date,
      Location: :location
    ]

  def name_mapping,
    # Invert type_mapping
    do: type_mapping() |> Enum.map(fn {k, v} -> {v, k} end) |> Enum.into(%{})

  def edit_custom_project_attribute(assigns) do
    ~H"""
    <div class={"relative group grid grid-cols-1 gap-4 mt-8 " <> (if Ecto.Changeset.get_field(@f_attr.source, :delete), do: "hidden", else: "")}>
      <%= hidden_input(@f_attr, :id) %>
      <div>
        <%= label(@f_attr, :name) %>
        <%= text_input(@f_attr, :name) %>
        <%= error_tag(@f_attr, :name) %>
      </div>
      <div class="ts-ignore">
        <%= label(@f_attr, :type) %>
        <%= select(
          @f_attr,
          :type,
          type_mapping()
          |> Enum.filter(fn {_, v} -> v != :location and v != :date end)
          |> Enum.map(fn {k, v} ->
            [
              key: k,
              value: v,
              disabled: not Enum.member?(ProjectAttribute.compatible_types(@f_attr.data.type), v)
            ]
          end),
          phx_debounce: 0,
          class:
            "block shadow-sm w-full rounded border border-gray-300 py-2 pl-3 pr-10 text-base focus:border-urge-500 focus:outline-none focus:ring-urge-500 sm:text-sm"
        ) %>
        <p class="support">After creation, modifying an attribute's type is limited.</p>
        <%= error_tag(@f_attr, :type) %>
      </div>
      <div>
        <%= label(@f_attr, :description) %>
        <%= text_input(@f_attr, :description) %>
        <%= error_tag(@f_attr, :description) %>
        <p class="support">
          Optional. The description will be displayed when editing this attribute.
        </p>
      </div>
      <%= if Ecto.Changeset.get_field(@f_attr.source, :type) in [:select, :multi_select] or Ecto.Changeset.get_field(@f_attr.source, :type) == nil do %>
        <div>
          <%= label(@f_attr, :options) %>
          <% id = "field-#{@f_attr.data.id}-options" %>
          <div id={id} phx-update="ignore">
            <div id={"child-#{id}"} x-data>
              <%= textarea(@f_attr, :options_json,
                class: "!hidden",
                id: "textarea-#{id}"
              ) %>
              <div>
                <textarea
                  interactive-tags
                  placeholder="Enter options for this attribute..."
                  class="input-base bg-white overflow-hidden break-all !pr-1"
                  data-feedback={"textarea-#{id}"}
                />
              </div>
            </div>
          </div>
          <%= error_tag(@f_attr, :options) %>
          <%= error_tag(@f_attr, :options_json) %>
          <p class="support">
            Press enter to add a new option.
          </p>
        </div>
      <% end %>
      <%= if Ecto.Changeset.get_field(@f_attr.source, :type) == :multi_select and @f_attr.data.type == :select do %>
        <div class="rounded-md bg-blue-50 p-4">
          <div class="flex">
            <div class="flex-shrink-0">
              <Heroicons.information_circle mini class="h-5 w-5 text-blue-400" />
            </div>
            <div class="ml-3 flex-1 md:flex md:justify-between">
              <p class="text-sm text-blue-700">
                Once you change this attribute to a multi-select, you will not be able to change it back to a single-select.
              </p>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def attribute_table_row(assigns) do
    ~H"""
    <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
      <%= @attr.label %>
    </td>
    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
      <%= @attr.type
      |> then(&Map.get(name_mapping(), &1)) %>
    </td>
    <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500 truncate hidden md:table-cell">
      <%= @attr.description |> Platform.Utils.truncate(40) %>
    </td>
    <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6 flex justify-end">
      <%= if @attr.schema_field == :project_attributes do %>
        <button
          :if={@show_edit_button}
          class="text-button"
          type="button"
          phx-click="open_modal"
          phx-value-id={@attr.name}
          phx-target={@myself}
        >
          <Heroicons.pencil_square mini class="h-5 w-5 text-urge-600" />
          <span class="sr-only">Edit <%= @attr.label %></span>
        </button>
      <% else %>
        <Heroicons.lock_closed
          class="h-5 w-5 text-gray-400"
          data-tooltip="This is a core attribute and cannot be edited."
        />
      <% end %>
    </td>
    """
  end

  def render(assigns) do
    ~H"""
    <article>
      <div class="grid grid-cols-1 gap-8 divide-y">
        <%= if Enum.member?(@show_panes, :general) do %>
          <.form
            :let={f}
            for={@general_changeset}
            id="general-form"
            phx-target={@myself}
            phx-submit="save_general"
            phx-change="validate_general"
            class="phx-form flex flex-col md:flex-row gap-4"
          >
            <%= if length(@show_panes) > 1 do %>
              <div class="mb-4 md:w-[20rem] md:mr-16">
                <p class="sec-head text-xl">General</p>
                <p class="sec-subhead">General information about the project.</p>
              </div>
            <% end %>
            <div class="flex flex-col gap-4 grow">
              <div
                :if={not @project.active}
                class="rounded-md bg-yellow-50 border border-yellow-300 p-4"
              >
                <div class="flex">
                  <div class="flex-shrink-0">
                    <Heroicons.archive_box mini class="h-5 w-5 text-yellow-600" />
                  </div>
                  <div class="ml-3">
                    <h3 class="text-sm font-medium text-yellow-800">
                      This project has been archived
                    </h3>
                    <div class="mt-2 text-sm text-yellow-700">
                      <p>
                        This project has been archived, so it is not possible to edit its data or incidents. To edit this project, you must unarchive it first.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
              <div>
                <%= label(f, :name) %>
                <%= text_input(f, :name,
                  placeholder: "What should we call this project?",
                  disabled: not Permissions.can_edit_project_metadata?(@current_user, @project)
                ) %>
                <%= error_tag(f, :name) %>
              </div>
              <div>
                <%= label(f, :code) %>
                <%= text_input(f, :code,
                  class: "uppercase font-mono",
                  placeholder: "E.g., CIV",
                  disabled: not Permissions.can_edit_project_metadata?(@current_user, @project)
                ) %>
                <%= error_tag(f, :code) %>
                <p class="support">
                  This is a short code that will be used to identify this project in incident IDs. E.g., CIV-1234.
                </p>
              </div>
              <div>
                <%= label(f, :description) %>
                <%= textarea(f, :description,
                  placeholder: "Provide a short description for the project...",
                  disabled: not Permissions.can_edit_project_metadata?(@current_user, @project)
                ) %>
                <%= error_tag(f, :description) %>
              </div>
              <div>
                <%= label(f, :color) %>
                <div id="color-picker" phx-update="ignore">
                  <div
                    class="flex gap-1 flex-wrap items-center"
                    x-data={"{active: '#{Ecto.Changeset.get_field(@general_changeset, :color)}'}"}
                  >
                    <%= for color <- ["#fb923c", "#fbbf24", "#a3e635", "#4ade80", "#2dd4bf", "#22d3ee", "#60a5fa", "#818cf8", "#a78bfa", "#c084fc", "#e879f9", "#f472b6"] do %>
                      <label class="!mt-0 cursor-pointer">
                        <%= radio_button(f, :color, color,
                          "x-model": "active",
                          class: "hidden",
                          disabled:
                            not Permissions.can_edit_project_metadata?(@current_user, @project)
                        ) %>
                        <svg
                          viewBox="0 0 100 100"
                          xmlns="http://www.w3.org/2000/svg"
                          fill={color}
                          class="h-7 w-7"
                          x-show={"active !== '#{color}'"}
                        >
                          <circle cx="50" cy="50" r="40" />
                        </svg>
                        <Heroicons.check_circle
                          mini
                          class="h-7 w-7"
                          style={"color: #{color}"}
                          x-show={"active === '#{color}'"}
                        />
                      </label>
                    <% end %>
                  </div>
                </div>
                <%= error_tag(f, :color) %>
                <p class="support">
                  This color will help visually identify the project.
                </p>
              </div>
              <div class="mt-8">
                <div class="flex justify-between gap-4 flex-wrap">
                  <div>
                    <%= submit("Save",
                      class: "button ~urge @high",
                      disabled: not Permissions.can_edit_project_metadata?(@current_user, @project)
                    ) %>
                  </div>
                  <%= if @project.id do %>
                    <div>
                      <%= if @project.active do %>
                        <button
                          phx-click="toggle_active"
                          data-confirm="Are you sure you want to archive this project? Incidents will no longer be editable."
                          class="button ~critical @high"
                          type="button"
                          phx-target={@myself}
                        >
                          Archive Project
                        </button>
                      <% else %>
                        <button
                          phx-click="toggle_active"
                          data-confirm="Are you sure you want to unarchive this project? Incidents will be editable again."
                          class="button ~critical @high"
                          type="button"
                          phx-target={@myself}
                        >
                          Unarchive Project
                        </button>
                      <% end %>
                    </div>
                  <% else %>
                    <button phx-click="close" class="base-button" type="button" phx-target={@myself}>
                      Cancel
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          </.form>
        <% end %>
        <%= if feature_available?(:custom_project_attributes) and Enum.member?(@show_panes, :custom_attributes) do %>
          <.form
            :let={f}
            for={@custom_attribute_changeset}
            id="attribute-form"
            phx-target={@myself}
            phx-submit="save_custom_attributes"
            phx-change="validate_custom_attributes"
            class="phx-form"
          >
            <div class="flex flex-col md:flex-row gap-4 pt-8">
              <%= if length(@show_panes) > 1 do %>
                <div class="mb-4 md:w-[20rem] md:mr-16 shrink-0">
                  <p class="sec-head text-xl">Attributes</p>
                  <p class="sec-subhead">
                    Define the data model for incidents in this project. You can add new attributes, or edit the existing ones.
                  </p>
                </div>
              <% end %>
              <fieldset class="flex flex-col mb-8 w-full">
                <%= if ProjectAttribute.does_project_have_default_attributes?(@project) and Permissions.can_edit_project_metadata?(@current_user, @project) do %>
                  <div class="rounded-md bg-blue-50 p-4 border-blue-600 border mb-8">
                    <div class="flex">
                      <div class="flex-shrink-0">
                        <Heroicons.information_circle mini class="h-5 w-5 text-blue-500" />
                      </div>
                      <div class="ml-3 flex-1 md:flex md:justify-between">
                        <p class="text-sm text-blue-700">
                          We've provided some default suggested attributes for this project. You can edit these attributes, or add new ones.
                        </p>
                      </div>
                    </div>
                  </div>
                <% end %>
                <div class="flow-root">
                  <div class="-mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
                    <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
                      <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg relative">
                        <table class="min-w-full divide-y divide-gray-300">
                          <thead class="bg-gray-50">
                            <tr>
                              <th
                                scope="col"
                                class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
                              >
                                Name
                              </th>
                              <th
                                scope="col"
                                class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900"
                              >
                                Type
                              </th>
                              <th
                                scope="col"
                                class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900 hidden md:block"
                              >
                                Description
                              </th>
                              <div scope="col" class="absolute right-3 top-3">
                                <button
                                  :if={
                                    Permissions.can_edit_project_metadata?(@current_user, @project)
                                  }
                                  type="button"
                                  phx-click="add_attr"
                                  phx-target={@myself}
                                  class="text-button text-sm"
                                  ,
                                >
                                  Add&nbsp;Attribute
                                </button>
                              </div>
                            </tr>
                          </thead>
                          <tbody class="divide-y divide-gray-200 bg-white">
                            <%= for f_attr <- inputs_for(f, :attributes) do %>
                              <%= if f_attr.data.id do %>
                                <tr x-data="{active: false}" class="group">
                                  <.attribute_table_row
                                    attr={ProjectAttribute.to_attribute(f_attr.data)}
                                    myself={@myself}
                                    show_edit_button={
                                      Permissions.can_edit_project_metadata?(@current_user, @project)
                                    }
                                  />
                                </tr>
                              <% end %>
                              <%= if (@actively_editing_id == f_attr.data.id) || (f_attr.data.id == nil and @actively_editing_id == :new) do %>
                                <.modal
                                  target={@myself}
                                  id={(@actively_editing_id || "nil") |> to_string()}
                                  js_on_close="document.cancelFormEvent($event)"
                                >
                                  <section class="mb-4">
                                    <h2 class="sec-head">Customize Attribute</h2>
                                  </section>
                                  <.edit_custom_project_attribute f_attr={f_attr} />
                                  <div class="mt-8 flex justify-between items-center">
                                    <div>
                                      <%= submit("Save", class: "button ~urge @high") %>
                                      <button
                                        type="button"
                                        phx-target={@myself}
                                        phx-click="close_modal"
                                        class="base-button"
                                        x-on:click="document.cancelFormEvent"
                                      >
                                        Cancel
                                      </button>
                                    </div>
                                    <%= if f_attr.data.id do %>
                                      <button
                                        type="button"
                                        phx-target={@myself}
                                        phx-click="delete_attr"
                                        phx-value-id={f_attr.data.id}
                                        data-confirm={"Are you sure you want to delete the attribute \"#{f_attr.data.name}\"? This action cannot be undone. This will remove this attribute from all incidents in this project."}
                                        data-tooltip="Delete this attribute"
                                        class="button ~critical @high"
                                      >
                                        Delete
                                      </button>
                                    <% end %>
                                  </div>
                                </.modal>
                              <% else %>
                                <div class="hidden">
                                  <.edit_custom_project_attribute f_attr={f_attr} />
                                </div>
                              <% end %>
                            <% end %>
                            <%= for attr <- Platform.Material.Attribute.active_attributes() |> Enum.filter(& &1.pane != :metadata && is_nil(&1.parent)) do %>
                              <tr>
                                <.attribute_table_row
                                  attr={attr}
                                  myself={@myself}
                                  show_edit_button={false}
                                />
                              </tr>
                            <% end %>
                          </tbody>
                        </table>
                      </div>
                    </div>
                  </div>
                </div>
              </fieldset>
            </div>
          </.form>
        <% end %>
      </div>
    </article>
    """
  end
end
