defmodule PlatformWeb.ProjectsLive.EditComponent do
  use PlatformWeb, :live_component

  alias Platform.Projects.{ProjectAttribute, ProjectAttributeGroup}
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
     |> close_modal()
     |> assign_new(:general_changeset, fn ->
       Projects.change_project(socket.assigns.project)
     end)
     |> assign_new(:custom_attribute_changeset, fn ->
       Projects.change_project(socket.assigns.project)
     end)
     |> assign_new(:all_attributes, fn ->
       Platform.Material.Attribute.active_attributes(project: socket.assigns.project)
     end)
     |> assign_new(:show_panes, fn -> [:general, :custom_attributes] end)}
  end

  defp close_modal(socket) do
    socket
    |> assign(:actively_editing_attribute_id, nil)
    |> assign(:actively_editing_group_id, nil)
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
      Projects.change_project(socket.assigns.project, attrs)
      |> Map.put(:action, :validate)
    )
    |> assign(
      :all_attributes,
      Platform.Material.Attribute.active_attributes(project: socket.assigns.project)
    )
  end

  defp get_core_attributes() do
    # Helper function to get core attributes
    Platform.Material.Attribute.active_attributes()
    |> Enum.filter(&(&1.pane != :metadata && is_nil(&1.parent)))
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

            {:noreply, socket |> assign(project: project) |> close_modal()}

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
         |> close_modal()
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
      |> assign(:actively_editing_attribute_id, :new)

    {:noreply, socket}
  end

  def handle_event("add_attr_group", _, socket) do
    socket =
      update(socket, :custom_attribute_changeset, fn changeset ->
        existing = Ecto.Changeset.get_field(changeset, :attribute_groups, [])

        Ecto.Changeset.put_embed(
          changeset,
          :attribute_groups,
          existing ++ [%ProjectAttributeGroup{}]
        )
      end)
      |> assign(:actively_editing_group_id, :new)

    {:noreply, socket}
  end

  def handle_event("edit_decorators", _, socket) do
    socket =
      update(socket, :custom_attribute_changeset, fn changeset ->
        all_existing_custom_attributes = Ecto.Changeset.get_field(changeset, :attributes, [])

        core_attribute_ids =
          get_core_attributes()
          |> Enum.filter(&(&1.allow_decorators != false))
          |> Enum.map(& &1.name)

        non_decorator_attributes =
          Enum.filter(all_existing_custom_attributes, &(&1.decorator_for == ""))

        decorator_attributes =
          Enum.filter(all_existing_custom_attributes, &(&1.decorator_for != ""))

        # Add any missing decorators to the changeset
        all_attribute_ids = Enum.map(non_decorator_attributes, & &1.id) ++ core_attribute_ids

        missing_decorator_ids =
          Enum.reject(all_attribute_ids, fn id ->
            Enum.any?(decorator_attributes, &(&1.decorator_for == to_string(id)))
          end)

        Ecto.Changeset.put_embed(
          changeset,
          :attributes,
          all_existing_custom_attributes ++
            Enum.map(missing_decorator_ids, fn id ->
              %ProjectAttribute{
                decorator_for: id,
                enabled: false,
                type: :select,
                name: "",
                id: Ecto.UUID.generate()
              }
            end)
        )
      end)
      |> assign(:actively_editing_attribute_id, :decorators)

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
     |> close_modal()
     |> assign_custom_attribute_changeset()}
  end

  def handle_event("delete_group", %{"id" => id}, socket) do
    # Delete the attribute group, save, and close the actively editing modal
    {:ok, project} =
      Projects.delete_project_attribute_group(
        socket.assigns.project,
        id,
        socket.assigns.current_user
      )

    send(self(), {:project_saved, project})

    {:noreply,
     socket
     |> assign(:project, project)
     |> assign(:actively_editing_group_id, nil)
     |> assign_custom_attribute_changeset()}
  end

  def handle_event("open_attr_edit_modal", %{"id" => id}, socket) do
    {:noreply, socket |> assign(:actively_editing_attribute_id, id)}
  end

  def handle_event("open_group_edit_modal", %{"id" => id}, socket) do
    {:noreply, socket |> assign(:actively_editing_group_id, id)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> close_modal()
     |> assign_custom_attribute_changeset()}
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

  def handle_event("reposition", params, socket) do
    # Ensure we have the latest project
    project = Platform.Projects.get_project!(socket.assigns.project.id)

    # Called when dragging an attribute to a new position
    %{"group" => group_id, "ordering" => ordering} = params

    case group_id do
      "group_ordering" ->
        # Reorder groups
        groups =
          Enum.map(project.attribute_groups, fn g ->
            idx =
              case g do
                %ProjectAttributeGroup{} -> Enum.find_index(ordering, &(&1 == g.id)) || 0
                _ -> 0
              end

            %{g | ordering: idx}
          end)
          |> Enum.sort_by(& &1.ordering)
          |> Enum.map(fn g -> Map.from_struct(g) end)

        # Update the project with the new groups
        {:ok, project} =
          Projects.update_project(
            project,
            %{attribute_groups: groups},
            socket.assigns.current_user
          )

        send(self(), {:project_saved, project})

        {:noreply, socket |> assign(project: project) |> assign_custom_attribute_changeset()}

      # For all the groups, if the group is the one we want to edit, update the ordering; if it's not, make sure that the none of the elements in the ordering are in that group
      _ ->
        new_groups =
          Enum.map(project.attribute_groups, fn g ->
            g =
              if g.id == group_id do
                %{g | member_ids: ordering}
              else
                %{
                  g
                  | member_ids: Enum.reject(g.member_ids, fn id -> Enum.member?(ordering, id) end)
                }
              end

            Map.from_struct(g)
          end)

        # Reorder the embedded attributes given their order in their respective
        # groups. This is also what allows us to sort unassigned attributes.
        new_attributes =
          Enum.map(project.attributes, fn e ->
            idx =
              case Enum.find(new_groups, &Enum.member?(&1.member_ids, e.id)) do
                # We can't find them in a group, so we check the given ordering
                # (which allows reordering if the attribute is in the unassigned
                # group)
                nil -> Enum.find_index(ordering, &(&1 == e.id)) || -1
                group -> Enum.find_index(group.member_ids, &(&1 == e.id)) || -1
              end

            Map.from_struct(%{e | ordering: idx})
          end)
          |> Enum.sort_by(& &1.ordering)

        # Update the project with the new groups
        {:ok, project} =
          Projects.update_project(
            socket.assigns.project,
            %{attribute_groups: new_groups, attributes: new_attributes},
            socket.assigns.current_user
          )

        send(self(), {:project_saved, project})

        {:noreply, socket |> assign(project: project) |> assign_custom_attribute_changeset()}
    end
  end

  def edit_custom_project_attribute(assigns) do
    # The attribute this is a decorator for
    assigns =
      assign_new(assigns, :decorator_for, fn -> nil end)
      |> assign(:enabled, Ecto.Changeset.get_field(assigns.f_attr.source, :enabled))
      |> assign_new(:id, fn -> "edit-#{Ecto.Changeset.get_field(assigns.f_attr.source, :id)}" end)

    ~H"""
    <div
      class={[
        "relative group grid grid-cols-1 gap-4",
        Ecto.Changeset.get_field(@f_attr.source, :delete) && "hidden"
      ]}
      id={@id}
    >
      <%= hidden_input(@f_attr, :id) %>
      <%= hidden_input(@f_attr, :decorator_for) %>

      <%= if is_nil(@decorator_for) do %>
        <%= hidden_input(@f_attr, :enabled) %>
      <% end %>

      <div
        :if={not is_nil(@decorator_for)}
        class="flex justify-between items-center w-full gap-4 group"
      >
        <span class={[
          "text-sm font-medium text-gray-900 grow flex items-center gap-2",
          @enabled && "cursor-pointer"
        ]}>
          <%= @decorator_for.label %>
        </span>
        <%= label(@f_attr, :enabled, class: "!flex items-center gap-2") do %>
          <span class="text-xs text-neutral-500 !font-normal">Enable</span>
          <%= checkbox(@f_attr, :enabled,
            "x-on:change": "if ($event.target.checked) { open = true; console.log('opening', open) }"
          ) %>
        <% end %>
      </div>
      <%= if not @enabled do %>
        <%= hidden_input(@f_attr, :name) %>
        <%= hidden_input(@f_attr, :type) %>
        <%= hidden_input(@f_attr, :description) %>
        <%= hidden_input(@f_attr, :options_json) %>
      <% end %>
      <div :if={@enabled} x-transition>
        <%= label(@f_attr, :name, class: "!text-neutral-600 !font-normal") %>
        <%= text_input(@f_attr, :name, class: "my-1") %>
        <%= error_tag(@f_attr, :name) %>
      </div>
      <div :if={@enabled} class={["ts-ignore"]} x-transition>
        <%= label(@f_attr, :type, class: "!text-neutral-600 !font-normal") %>
        <%= select(
          @f_attr,
          :type,
          type_mapping()
          |> Enum.filter(fn {_, v} ->
            (v != :location and v != :date and v != :text) || is_nil(@decorator_for)
          end)
          |> Enum.map(fn {k, v} ->
            [
              key: k,
              value: v,
              disabled:
              not is_nil(Ecto.Changeset.get_field(@f_attr.source, :id)) and not Enum.member?(
                  ProjectAttribute.compatible_types(Ecto.Changeset.get_field(@f_attr.source, :type)),
                  v
                )
            ]
          end),
          phx_debounce: 0,
          class:
            "block shadow-sm w-full rounded border border-gray-300 my-1 py-2 pl-3 pr-10 text-base focus:border-urge-500 focus:outline-none focus:ring-urge-500 sm:text-sm"
        ) %>
        <p class="support">After creation, modifying an attribute's type is limited.</p>
        <%= error_tag(@f_attr, :type) %>
      </div>
      <div :if={@enabled} x-transition>
        <%= label(@f_attr, :description, class: "!text-neutral-600 !font-normal") %>
        <%= text_input(@f_attr, :description, class: "my-1") %>
        <%= error_tag(@f_attr, :description) %>
        <p class="support">
          Optional. The description will be displayed when editing this attribute.
        </p>
      </div>
      <%= if (Ecto.Changeset.get_field(@f_attr.source, :type) in [:select, :multi_select] or Ecto.Changeset.get_field(@f_attr.source, :type) == nil) do %>
        <div :if={@enabled} x-transition>
          <%= label(@f_attr, :options, class: "!text-neutral-600 !font-normal") %>
          <% id = "field-#{Ecto.Changeset.get_field(@f_attr.source, :id)}-options" %>
          <div id={id} phx-update="ignore" class="my-1">
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
      <%= if Ecto.Changeset.get_field(@f_attr.source, :type) == :multi_select and Ecto.Changeset.get_field(@f_attr.source, :type) == :select do %>
        <div :if={@enabled} class={["rounded-md bg-blue-50 p-4"]} x-transition>
          <div class="flex">
            <div class="flex-shrink-0">
              <Heroicons.information_circle mini class="h-5 w-5 text-blue-400" />
            </div>
            <div class="ml-3 flex-1 lg:flex lg:justify-between">
              <p class="text-sm text-blue-700">
                Once you change to a multi-select, you will not be able to change back to a single-select.
              </p>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def edit_attribute_group(assigns) do
    ~H"""
    <%= inputs_for @f, :attribute_groups, [multipart: true, id: "attr-group-form-#{@group_id}"], fn ef -> %>
      <%= if ef.data.id == @group_id or (is_nil(ef.data.id) and @group_id == :new) do %>
        <div
          class={[
            "relative group grid grid-cols-1 gap-4",
            Ecto.Changeset.get_field(ef.source, :delete) && "hidden"
          ]}
          id={"group-editor-#{@group_id}-#{@group_ordering}"}
        >
          <div>
            <%= label(ef, :name, class: "!text-neutral-600 !font-normal") %>
            <%= text_input(ef, :name, class: "my-1") %>
            <%= error_tag(ef, :name) %>
          </div>
          <div>
            <%= label(ef, :description, class: "!text-neutral-600 !font-normal") %>
            <%= text_input(ef, :description, class: "my-1") %>
            <%= error_tag(ef, :description) %>
            <p class="support">
              Optional. The description will be displayed with this attribute group to provide additional context.
            </p>
          </div>
          <div>
            <%= label(ef, :color, class: "!text-neutral-600 !font-normal") %>
            <div id={"color-picker-#{@group_id}-#{@group_ordering}"} phx-update="ignore">
              <div
                class="flex gap-1 flex-wrap items-center"
                x-data={"{active: '#{Ecto.Changeset.get_field(ef.source, :color)}'}"}
              >
                <%= for color <- ["#808080", "#fb923c", "#fbbf24", "#a3e635", "#4ade80", "#2dd4bf", "#22d3ee", "#60a5fa", "#818cf8", "#a78bfa", "#c084fc", "#e879f9", "#f472b6"] do %>
                  <label class="!mt-0 cursor-pointer">
                    <%= radio_button(ef, :color, color,
                      "x-model": "active",
                      class: "hidden"
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
            <%= error_tag(ef, :color) %>
            <p class="support">
              This color will help visually identify the attribute group.
            </p>
          </div>
          <div class="mt-4">
            <p class="flex gap-2 items-center mb-1">
              <%= checkbox(ef, :show_in_creation_form) %>
              <%= label(ef, :show_in_creation_form, class: "!text-neutral-600 !font-normal") do %>
                Include this group in the incident creation window
              <% end %>
            </p>
            <p class="support">
              If enabled, the attributes in this group are included in the incident creation window. If disabled, the group's attributes aren't shown in the incident creation window but can still be edited directly on the incident page.
            </p>
            <%= error_tag(ef, :show_in_creation_form) %>
          </div>
        </div>
      <% end %>
    <% end %>
    """
  end

  def decorator_description(assigns) do
    ~H"""
    <span>
      Decorators capture additional data for each attribute. For example, you can use decorators to associate confidence values with each attribute value.
    </span>
    """
  end

  def attribute_table_row(assigns) do
    ~H"""
    <div class="grid grid-cols-2 md:grid-cols-4 drag-ghost:rounded drag-ghost:opacity-50 drag-ghost:bg-neutral-50">
      <div class="whitespace-nowrap py-4 flex items-center pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
        <Heroicons.arrows_up_down
          :if={@editable}
          mini
          class="h-4 w-4 cursor-pointer text-gray-400 mr-2 -ml-2 handle"
          data-tooltip="Drag to move this attribute"
        />
        <%= @attr.label %>
      </div>
      <div class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
        <%= @attr.type
        |> then(&Map.get(name_mapping(), &1)) %>
      </div>
      <div class="whitespace-nowrap px-3 py-4 text-sm text-gray-500 truncate hidden lg:table-cell">
        <%= @attr.description |> Platform.Utils.truncate(40) %>
      </div>
      <div class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6 flex justify-end">
        <%= if @attr.schema_field == :project_attributes do %>
          <button
            :if={@editable}
            class="text-button"
            type="button"
            phx-click="open_attr_edit_modal"
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
      </div>
    </div>
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
            class="phx-form flex flex-col lg:flex-row gap-4"
          >
            <%= if length(@show_panes) > 1 do %>
              <div class="mb-4 lg:w-[20rem] lg:mr-16">
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
              <details class="flex flex-col gap-4">
                <summary class="text-button cursor-pointer text-sm">Advanced options</summary>
                <div class="mt-4">
                  <p class="flex gap-2 items-center mb-1">
                    <%= checkbox(f, :should_sync_with_internet_archive,
                      disabled: not Permissions.can_edit_project_metadata?(@current_user, @project)
                    ) %>
                    <%= label(f, :should_sync_with_internet_archive) do %>
                      Share with the Internet Archive
                    <% end %>
                  </p>
                  <p class="support">
                    If enabled, links added to this project as source material will be automatically archived by the <a href="https://archive.org">Internet Archive</a>.
                  </p>
                  <%= error_tag(f, :should_sync_with_internet_archive) %>
                </div>
              </details>
              <div class="mt-8">
                <div class="flex justify-between gap-4 flex-wrap">
                  <div>
                    <%= submit("Save",
                      class: "button ~urge @high",
                      disabled: not Permissions.can_edit_project_metadata?(@current_user, @project)
                    ) %>
                  </div>
                  <%= if not is_nil(@project.id) do %>
                    <div :if={Permissions.can_change_project_active_status?(@current_user, @project)}>
                      <%= if @project.active do %>
                        <button
                          phx-click="toggle_active"
                          data-confirm="Are you sure you want to archive this project? Incidents will no longer be editable."
                          class="button ~critical @high"
                          type="button"
                          phx-target={@myself}
                          data-tooltip="Archiving a project freezes its data and prevents all members from creating or editing its incidents."
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
                          data-tooltip="Archiving a project freezes its data and prevents all members from creating or editing its incidents."
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
            <div class="flex flex-col lg:flex-row gap-4 pt-8">
              <%= if length(@show_panes) > 1 do %>
                <div class="mb-4 lg:w-[20rem] lg:mr-16 shrink-0">
                  <p class="sec-head text-xl">Attributes</p>
                  <p class="sec-subhead">
                    Define the data model for incidents in this project. You can add new attributes, or edit the existing ones.
                  </p>
                  <div class="flex gap-2 mt-8">
                    <button
                      :if={Permissions.can_edit_project_metadata?(@current_user, @project)}
                      type="button"
                      phx-click="add_attr_group"
                      phx-target={@myself}
                      class="button ~urge @high"
                      ,
                    >
                      <Heroicons.plus mini class="-ml-0.5 mr-2 text-urge-200 h-5 w-5" />
                      Add&nbsp;Group
                    </button>
                    <button
                      :if={Permissions.can_edit_project_metadata?(@current_user, @project)}
                      type="button"
                      phx-click="add_attr"
                      phx-target={@myself}
                      class="button ~urge @high"
                      ,
                    >
                      <Heroicons.plus mini class="-ml-0.5 mr-2 text-urge-200 h-5 w-5" />
                      Add&nbsp;Attribute
                    </button>
                  </div>
                </div>
              <% end %>
              <fieldset class="flex flex-col mb-8 w-full">
                <%= if ProjectAttribute.does_project_have_default_attributes?(@project) and Permissions.can_edit_project_metadata?(@current_user, @project) do %>
                  <div class="rounded-md bg-blue-50 p-4 border-blue-600 border mb-8">
                    <div class="flex">
                      <div class="flex-shrink-0">
                        <Heroicons.information_circle mini class="h-5 w-5 text-blue-500" />
                      </div>
                      <div class="ml-3 flex-1 lg:flex lg:justify-between">
                        <p class="text-sm text-blue-700">
                          We've provided some default suggested attributes for this project. You can edit these attributes, or add new ones.
                        </p>
                      </div>
                    </div>
                  </div>
                <% end %>
                <div class="flow-root">
                  <div class="-mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
                    <.modal
                      :if={@actively_editing_group_id == :new}
                      target={@myself}
                      id="new_group_editor"
                      js_on_close="document.cancelFormEvent($event)"
                    >
                      <section class="mb-6">
                        <h2 class="sec-head">Create Group</h2>
                      </section>
                      <.edit_attribute_group f={f} group_id={:new} group_ordering={-1} />
                      <div class="mt-8 flex justify-between items-center">
                        <div class="flex items-center gap-2">
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
                      </div>
                    </.modal>
                    <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8 flex flex-col">
                      <div
                        data-list_id="group_ordering"
                        data-list_group="group_ordering"
                        phx-target={@myself}
                        phx-hook="Sortable"
                        id="attr-list"
                      >
                        <% attr_ids_to_group =
                          Enum.flat_map(@project.attribute_groups, fn attr_group ->
                            Enum.map(attr_group.member_ids, &{&1, attr_group.id})
                          end)
                          |> Enum.into(%{}) %>
                        <section
                          :for={group <- [:core, :unassigned] ++ @project.attribute_groups}
                          data-sortable-id={if is_atom(group), do: group, else: to_string(group.id)}
                          data-sortable-fixed={is_atom(group)}
                          class="mb-6"
                        >
                          <% group_id = if is_atom(group), do: group, else: to_string(group.id) %>
                          <div
                            class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg relative"
                            style={if not is_atom(group), do: "border-left: 4px solid #{group.color}"}
                          >
                            <div class="min-w-full">
                              <div class="bg-gray-50 pt-3 flex items-center gap-2 px-4">
                                <h3
                                  :if={
                                    Permissions.can_edit_project_metadata?(
                                      @current_user,
                                      @project
                                    ) and not is_atom(group)
                                  }
                                  class="text-neutral-600 font-medium text-sm flex items-center"
                                >
                                  <Heroicons.arrows_up_down
                                    mini
                                    class="h-4 w-4 cursor-pointer text-gray-400 handle"
                                    data-tooltip="Drag to move this group"
                                  />
                                </h3>
                                <span class="pr-6 text-left text-sm font-medium text-gray-900">
                                  <%= case group do %>
                                    <% :unassigned -> %>
                                      Ungrouped Attributes
                                    <% :core -> %>
                                      Core Attributes
                                    <% _ -> %>
                                      <%= group.name %>
                                  <% end %>
                                </span>
                                <span class="grow" />
                                <button
                                  :if={
                                    Permissions.can_edit_project_metadata?(
                                      @current_user,
                                      @project
                                    ) and not is_atom(group)
                                  }
                                  class="text-button text-sm"
                                  type="button"
                                  phx-click="open_group_edit_modal"
                                  phx-value-id={group.id}
                                  phx-target={@myself}
                                >
                                  Edit Group
                                </button>
                              </div>
                              <p class="text-xs text-neutral-500 mx-4 mt-2 mb-3">
                                <%= case group do %>
                                  <% :unassigned -> %>
                                    Ungrouped attributes are not associated with any group.
                                  <% :core -> %>
                                    Core attributes are required for all incidents. You can't modify core attributes.
                                  <% _ -> %>
                                    <%= group.description %>
                                <% end %>
                              </p>
                              <div class="bg-white border-t">
                                <%= case group do %>
                                  <% :core -> %>
                                    <div :for={attr <- get_core_attributes()} :if={group == :core}>
                                      <.attribute_table_row
                                        attr={attr}
                                        myself={@myself}
                                        editable={false}
                                      />
                                    </div>
                                  <% _ -> %>
                                    <%= if to_string(@actively_editing_group_id) == group_id do %>
                                      <.modal
                                        target={@myself}
                                        id={@actively_editing_group_id |> to_string()}
                                        js_on_close="document.cancelFormEvent($event)"
                                      >
                                        <section class="mb-6">
                                          <h2 class="sec-head">Edit Group</h2>
                                        </section>
                                        <.edit_attribute_group
                                          f={f}
                                          group_id={group_id}
                                          group_ordering={group.ordering}
                                        />
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
                                          <button
                                            type="button"
                                            phx-target={@myself}
                                            phx-click="delete_group"
                                            phx-value-id={group_id}
                                            data-confirm={"Are you sure you want to delete the group \"#{group.name}\"? This action cannot be undone. Attributes in this group will be moved to the unassigned group and will not be deleted."}
                                            data-tooltip="Delete this group (without deleting its attributes)"
                                            class="button ~critical @high"
                                          >
                                            Delete
                                          </button>
                                        </div>
                                      </.modal>
                                    <% else %>
                                      <div class="hidden">
                                        <.edit_attribute_group
                                          f={f}
                                          group_id={group_id}
                                          group_ordering={
                                            if is_atom(group), do: -1, else: group.ordering
                                          }
                                        />
                                      </div>
                                    <% end %>
                                    <div
                                      data-list_id={group_id}
                                      data-list_group="attribute_ordering"
                                      phx-target={@myself}
                                      id={group_id}
                                      phx-hook="Sortable"
                                      data-sortable={to_string(group != :core)}
                                    >
                                      <div class="text-sm text-neutral-500 p-4 sibling-sortable-hidden">
                                        There are no attributes in this group. Drag attributes into this group to add them.
                                      </div>
                                      <.inputs_for
                                        :let={f_attr}
                                        id={"attr-form-#{group_id}"}
                                        field={f[:attributes]}
                                      >
                                        <% attr_group_id =
                                          attr_ids_to_group[
                                            Ecto.Changeset.get_field(f_attr.source, :id)
                                          ] || :unassigned %>
                                        <%= if Ecto.Changeset.get_field(f_attr.source, :decorator_for) == "" and (attr_group_id == group_id) do %>
                                          <div data-sortable-id={
                                            Ecto.Changeset.get_field(f_attr.source, :id)
                                          }>
                                            <div x-data="{active: false}" class="group">
                                              <.attribute_table_row
                                                attr={ProjectAttribute.to_attribute(f_attr.data)}
                                                myself={@myself}
                                                editable={
                                                  Permissions.can_edit_project_metadata?(
                                                    @current_user,
                                                    @project
                                                  )
                                                }
                                              />
                                            </div>
                                            <%= if @actively_editing_attribute_id == Ecto.Changeset.get_field(f_attr.source, :id) or (is_nil(Ecto.Changeset.get_field(f_attr.source, :id)) and @actively_editing_attribute_id == :new) do %>
                                              <.modal
                                                target={@myself}
                                                id={
                                                  (@actively_editing_attribute_id || "nil")
                                                  |> to_string()
                                                }
                                                js_on_close="document.cancelFormEvent($event)"
                                              >
                                                <section class="mb-6">
                                                  <h2 class="sec-head">Edit Custom Attribute</h2>
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
                                                  <%= if Ecto.Changeset.get_field(f_attr.source, :id) do %>
                                                    <button
                                                      type="button"
                                                      phx-target={@myself}
                                                      phx-click="delete_attr"
                                                      phx-value-id={
                                                        Ecto.Changeset.get_field(f_attr.source, :id)
                                                      }
                                                      data-confirm={"Are you sure you want to delete the attribute \"#{Ecto.Changeset.get_field(f_attr.source, :name)}\"? This action cannot be undone. This will remove this attribute from all incidents in this project."}
                                                      data-tooltip="Delete this attribute"
                                                      class="button ~critical @high"
                                                    >
                                                      Delete
                                                    </button>
                                                  <% end %>
                                                </div>
                                              </.modal>
                                            <% else %>
                                              <div
                                                :if={
                                                  @actively_editing_attribute_id != :decorators ||
                                                    Ecto.Changeset.get_field(
                                                      f_attr.source,
                                                      :decorator_for
                                                    ) == ""
                                                }
                                                class="hidden"
                                              >
                                                <.edit_custom_project_attribute f_attr={f_attr} />
                                              </div>
                                            <% end %>
                                          </div>
                                        <% end %>
                                      </.inputs_for>
                                    </div>
                                <% end %>
                              </div>
                            </div>
                          </div>
                        </section>
                        <%= if @actively_editing_attribute_id == :decorators do %>
                          <.modal
                            target={@myself}
                            id="decorator_edit"
                            js_on_close="document.cancelFormEvent($event)"
                          >
                            <section class="mb-4">
                              <h2 class="sec-head">Manage Decorators</h2>
                              <p class="sec-subhead">
                                <.decorator_description />
                              </p>
                            </section>
                            <div class="flex flex-col mt-12">
                              <.inputs_for
                                :let={f_attr}
                                field={f[:attributes]}
                                id="edit-decorator"
                                skip_hidden={true}
                              >
                                <% parent =
                                  Enum.find(
                                    @all_attributes,
                                    &(to_string(&1.name) ==
                                        to_string(
                                          Ecto.Changeset.get_field(f_attr.source, :decorator_for)
                                        ))
                                  ) %>
                                <div
                                  :if={
                                    Ecto.Changeset.get_field(f_attr.source, :decorator_for) != "" and
                                      parent.allow_decorators != false
                                  }
                                  class="border-t -mx-6 px-6 py-4"
                                >
                                  <.edit_custom_project_attribute
                                    f_attr={f_attr}
                                    decorator_for={parent}
                                    allow_disable={true}
                                    id={"edit-decorator-#{Ecto.Changeset.get_field(f_attr.source, :decorator_for)}"}
                                  />
                                </div>
                              </.inputs_for>
                            </div>
                            <div class="flex justify-between items-center border-t -mx-6 px-6 pt-12">
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
                            </div>
                          </.modal>
                        <% end %>
                      </div>
                      <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg relative divide-y divide-gray-300">
                        <div class="bg-gray-50 flex items-center justify-between px-4 sm:px-6">
                          <p class="py-3.5 text-left text-sm font-medium text-gray-900">
                            Decorators
                          </p>
                          <button
                            :if={Permissions.can_edit_project_metadata?(@current_user, @project)}
                            type="button"
                            phx-click="edit_decorators"
                            phx-target={@myself}
                            class="text-button text-sm"
                          >
                            Edit Decorators
                          </button>
                        </div>
                        <div class="p-4 sm:p-6 bg-white">
                          <% decorators = @all_attributes |> Enum.filter(& &1.is_decorator) %>
                          <p class="text-sm text-neutral-600">
                            <.decorator_description />
                            <span :if={Enum.empty?(decorators)}>
                              You have not enabled any decorators.
                            </span>
                            <span :if={not Enum.empty?(decorators)}>
                              You have enabled the following decorators:
                            </span>
                          </p>
                          <div :if={not Enum.empty?(decorators)} class="flex gap-2 flex-wrap mt-4">
                            <div
                              :for={attr <- decorators}
                              class="px-2 py-1 text-left text-xs rounded-full border font-medium text-gray-700 bg-neutral-100"
                            >
                              <% parent =
                                Enum.find(
                                  @all_attributes,
                                  &(to_string(&1.name) == to_string(attr.parent))
                                ) %>
                              <%= parent.label %>: <%= attr.label %>
                            </div>
                          </div>
                        </div>
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
