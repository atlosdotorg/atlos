defmodule PlatformWeb.ProjectsLive.EditComponent do
  use PlatformWeb, :live_component

  alias Platform.Projects.ProjectAttribute
  alias Ecto.UUID
  alias Platform.Auditor
  alias Platform.Projects

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)

    {:ok,
     socket
     |> assign_new(:project, fn -> %Projects.Project{} end)
     |> assign(:actively_editing_id, nil)
     |> assign_new(:general_changeset, fn ->
       Projects.change_project(socket.assigns.project)
     end)
     |> assign_new(:custom_attribute_changeset, fn ->
       Projects.change_project(socket.assigns.project)
     end)}
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

  def handle_event("delete", _params, socket) do
    if Projects.can_edit_project?(socket.assigns.current_user, socket.assigns.project) do
      Projects.delete_project(socket.assigns.project)
      Auditor.log(:project_deleted, %{project: socket.assigns.project}, socket)
      send(self(), {:project_deleted, nil})
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
      Date: :date
    ]

  def name_mapping,
    # Invert type_mapping
    do: type_mapping() |> Enum.map(fn {k, v} -> {v, k} end) |> Enum.into(%{})

  def edit_custom_project_attribute(assigns) do
    ~H"""
    <div class={"relative group grid grid-cols-1 md:grid-cols-2 gap-4 " <> (if Ecto.Changeset.get_field(@f_attr.source, :delete), do: "hidden", else: "")}>
      <%= hidden_inputs_for(@f_attr) %>
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
        <%= error_tag(@f_attr, :type) %>
      </div>
      <%= if Ecto.Changeset.get_field(@f_attr.source, :type) in [:select, :multi_select] or Ecto.Changeset.get_field(@f_attr.source, :type) == nil do %>
        <div class="col-span-2">
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
          <p class="support">
            Press enter to add a new option.
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  def attribute_preview(assigns) do
    ~H"""
    <div class="flex w-full justify-between items-baseline">
      <h3 class="font-medium">
        <%= @f_attr.data.name %>
      </h3>
      <p class="text-sm text-gray-500">
        <%= if @f_attr.source.valid? do %>
          <%= @f_attr.data.type
          |> then(&Map.get(name_mapping(), &1)) %>
        <% else %>
          <span class="text-critical-500">Invalid</span>
        <% end %>
      </p>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <article>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 divide-x mb-8">
        <.form
          :let={f}
          for={@general_changeset}
          id="general-form"
          phx-target={@myself}
          phx-submit="save_general"
          phx-change="validate_general"
          class="phx-form flex flex-col gap-4"
        >
          <div class="mb-4">
            <p class="sec-head text-xl">General</p>
            <p class="sec-subhead">General information about the project.</p>
          </div>
          <div>
            <%= label(f, :name) %>
            <%= text_input(f, :name, placeholder: "What should we call this project?") %>
            <%= error_tag(f, :name) %>
          </div>
          <div>
            <%= label(f, :code) %>
            <%= text_input(f, :code, class: "uppercase font-mono", placeholder: "E.g., CIV") %>
            <%= error_tag(f, :code) %>
            <p class="support">
              This is a short code that will be used to identify this project in incident IDs. E.g., CIV-1234.
            </p>
          </div>
          <div>
            <%= label(f, :description) %>
            <%= textarea(f, :description,
              placeholder: "Provide a short description for the project..."
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
                <%= for color <- ["#f87171", "#fb923c", "#fbbf24", "#a3e635", "#4ade80", "#2dd4bf", "#22d3ee", "#60a5fa", "#818cf8", "#a78bfa", "#c084fc", "#e879f9", "#f472b6", "#fb7185"] do %>
                  <label class="!mt-0 cursor-pointer">
                    <%= radio_button(f, :color, color, "x-model": "active", class: "hidden") %>
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
                <%= submit("Save", class: "button ~urge @high") %>
                <button phx-click="close" class="base-button" type="button" phx-target={@myself}>
                  Cancel
                </button>
              </div>
              <%= if @project.id do %>
                <div>
                  <button
                    phx-click="delete"
                    data-confirm="Are you sure you want to delete this project? This action cannot be undone. This will not delete the incidents that are part of this project."
                    class="button ~critical @high"
                    type="button"
                    phx-target={@myself}
                  >
                    Delete
                  </button>
                </div>
              <% end %>
            </div>
          </div>
        </.form>
        <%= if feature_available?(:custom_project_attributes) do %>
          <.form
            :let={f}
            for={@custom_attribute_changeset}
            id="attribute-form"
            phx-target={@myself}
            phx-submit="save_custom_attributes"
            phx-change="validate_custom_attributes"
            class="phx-form"
          >
            <div class="flex flex-col gap-4 lg:pl-8">
              <div class="mb-4">
                <p class="sec-head text-xl">Project Attributes</p>
                <p class="sec-subhead">Specify your data model for incidents in this project.</p>
              </div>
              <fieldset class="flex flex-col">
                <%= for f_attr <- inputs_for(f, :attributes) do %>
                  <div x-data="{active: false}" class="group">
                    <%= if f_attr.data.id do %>
                      <button
                        class={"p-4 mb-4 bg-white border hover:bg-neutral-50 transition-all rounded-lg shadow-sm overflow-hidden w-full " <> (if not f_attr.source.valid?, do: "ring-2 ring-critical-500", else: "")}
                        type="button"
                        phx-click="open_modal"
                        phx-value-id={f_attr.data.id}
                        phx-target={@myself}
                      >
                        <.attribute_preview f_attr={f_attr} />
                      </button>
                    <% end %>
                    <%= if (@actively_editing_id == f_attr.data.id) || (f_attr.data.id == nil and @actively_editing_id == :new) do %>
                      <.modal target={@myself}>
                        <section class="mb-4">
                          <h2 class="sec-head">Edit Attribute</h2>
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
                              data-confirm="Are you sure you want to delete this attribute?"
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
                  </div>
                <% end %>
                <div>
                  <button
                    type="button"
                    phx-click="add_attr"
                    phx-target={@myself}
                    class="text-button text-sm"
                  >
                    + Add Attribute
                  </button>
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
