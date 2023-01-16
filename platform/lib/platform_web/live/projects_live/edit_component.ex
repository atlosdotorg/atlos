defmodule PlatformWeb.ProjectsLive.EditComponent do
  use PlatformWeb, :live_component

  alias Platform.Auditor
  alias Platform.Projects

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:project, fn -> %Projects.Project{} end)
     |> assign_changeset()}
  end

  def assign_changeset(socket, attrs \\ %{}) do
    socket |> assign(:changeset, Projects.change_project(socket.assigns.project, attrs))
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

  def handle_event("validate", %{"project" => project_params}, socket) do
    {:noreply, socket |> assign_changeset(project_params) |> Map.put(:action, :validate)}
  end

  def handle_event("save", %{"project" => project_params}, socket) do
    case socket.assigns.project.id do
      nil ->
        case Projects.create_project(project_params, socket.assigns.current_user) do
          {:ok, project} ->
            send(self(), {:close, project})
            {:noreply, socket |> assign(project: project)}

          {:error, changeset} ->
            {:noreply, socket |> assign(:changeset, changeset)}
        end

      _project_id ->
        case Projects.update_project(
               socket.assigns.project,
               project_params,
               socket.assigns.current_user
             ) do
          {:ok, project} ->
            send(self(), {:project_saved, project})
            {:noreply, socket |> assign(project: project)}

          {:error, changeset} ->
            {:noreply, socket |> assign(:changeset, changeset)}
        end
    end
  end

  def handle_event("add_attr", _, socket) do
    socket =
      update(socket, :changeset, fn changeset ->
        existing = Ecto.Changeset.get_field(changeset, :attributes, [])
        Ecto.Changeset.put_embed(changeset, :attributes, existing ++ [%{}])
      end)

    {:noreply, socket}
  end

  def handle_event("delete_attr", %{"index" => index}, socket) do
    index = String.to_integer(index)
    changeset = socket.assigns.changeset

    existing = Ecto.Changeset.get_field(changeset, :attributes, [])
    elem = Enum.at(existing, index)

    changeset =
      if elem.id do
        # Will be handled by the form's `delete` field
        changeset
      else
        Ecto.Changeset.put_embed(
          changeset,
          :attributes,
          List.delete_at(existing, index)
        )
      end

    socket = assign(socket, :changeset, changeset)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <article>
      <.form
        :let={f}
        for={@changeset}
        id="project-form"
        phx-target={@myself}
        phx-submit="save"
        phx-change="validate"
        class="phx-form flex flex-col gap-8 divide-y mb-8"
      >
        <div class="flex flex-col gap-4">
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
                x-data={"{active: '#{Ecto.Changeset.get_field(@changeset, :color)}'}"}
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
        </div>
        <div class="flex flex-col gap-4 pt-8">
          <div class="mb-4">
            <p class="sec-head text-xl">Attributes</p>
            <p class="sec-subhead">Specify your data model for incidents in this project.</p>
          </div>
          <fieldset class="flex flex-col gap-4">
            <%= hidden_input(f, :attributes, value: "[]") %>
            <%= for f_attr <- inputs_for(f, :attributes) do %>
              <div class={"relative group grid grid-cols-1 md:grid-cols-2 gap-4 p-4 rounded border bg-neutral-100 " <> (if Ecto.Changeset.get_field(f_attr.source, :delete), do: "hidden", else: "")}>
                <%= hidden_inputs_for(f_attr) %>
                <%= hidden_input(f_attr, :id) %>
                <div>
                  <%= label(f_attr, :name) %>
                  <%= text_input(f_attr, :name) %>
                  <%= error_tag(f_attr, :name) %>
                </div>
                <div class="ts-ignore">
                  <%= label(f_attr, :type) %>
                  <%= select(
                    f_attr,
                    :type,
                    %{
                      "Single Select": :select,
                      "Multiple Select": :multi_select,
                      Date: :date,
                      Text: :text
                    },
                    phx_debounce: 0,
                    class:
                      "block shadow-sm w-full rounded border border-gray-300 py-2 pl-3 pr-10 text-base focus:border-urge-500 focus:outline-none focus:ring-urge-500 sm:text-sm"
                  ) %>
                  <%= error_tag(f_attr, :type) %>
                </div>
                <%= if Ecto.Changeset.get_field(f_attr.source, :type) in [:select, :multi_select] do %>
                  <div class="col-span-2">
                    <%= label(f_attr, :options) %>
                    <% id = "field-#{f_attr.data.id}-options" %>
                    <div id={id} phx-update="ignore">
                      <div id={"child-#{id}"} x-data>
                        <%= textarea(f_attr, :options_json,
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
                    <%= error_tag(f_attr, :options) %>
                    <p class="support">
                      Press enter to add a new option.
                    </p>
                  </div>
                <% end %>
                <div class="absolute transition-all opacity-0 group-hover:opacity-100 group-focus-within:opacity-100 right-0 top-0 p-2">
                  <label>
                    <%= if f_attr.data.id do %>
                      <label data-tooltip="Delete this attribute">
                        <%= checkbox(f_attr, :delete,
                          "x-bind:checked": "deleted",
                          "data-confirm": "Are you sure you want to delete this attribute?",
                          class: "hidden"
                        ) %>
                        <Heroicons.x_circle mini class="h-5 w-5 text-red-400 cursor-pointer" />
                      </label>
                    <% else %>
                      <button
                        type="button"
                        phx-target={@myself}
                        phx-click="delete_attr"
                        phx-value-index={f_attr.index}
                        data-confirm="Are you sure you want to delete this attribute?"
                        data-tooltip="Delete this attribute"
                      >
                        <Heroicons.x_circle mini class="h-5 w-5 text-red-400" />
                      </button>
                    <% end %>
                  </label>
                </div>
              </div>
            <% end %>
            <div>
              <button
                type="button"
                phx-click="add_attr"
                phx-target={@myself}
                class="text-button text-sm"
              >
                + Add Custom Attribute
              </button>
            </div>
          </fieldset>
        </div>
        <div class="pt-8">
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
    </article>
    """
  end
end
