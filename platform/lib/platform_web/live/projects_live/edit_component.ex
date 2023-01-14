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
    {:noreply, socket |> assign_changeset(project_params)}
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
            {:noreply, socket |> assign_changeset(changeset)}
        end
    end
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
        class="phx-form flex flex-col gap-4"
      >
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
          <%= textarea(f, :description, placeholder: "Provide a short description for the project...") %>
          <%= error_tag(f, :description) %>
        </div>
        <div>
          <%= label(f, :color) %>
          <div id="color-picker" phx-update="ignore">
            <div class="flex gap-1 flex-wrap items-center" x-data={"{active: '#{Ecto.Changeset.get_field(@changeset, :color)}'}"}>
              <%= for color <- ["#f87171", "#fb923c", "#fbbf24", "#a3e635", "#4ade80", "#2dd4bf", "#22d3ee", "#60a5fa", "#818cf8", "#a78bfa", "#c084fc", "#e879f9", "#f472b6", "#fb7185"] do %>
                <label class="!mt-0">
                  <%= radio_button(f, :color, color, "x-model": "active", class: "hidden")%>
                  <svg
                    viewBox="0 0 100 100"
                    xmlns="http://www.w3.org/2000/svg"
                    fill={color}
                    class="h-7 w-7"
                    x-show={"active !== '#{color}'"}
                  >
                    <circle cx="50" cy="50" r="40" />
                  </svg>
                  <Heroicons.check_circle mini class="h-7 w-7" style={"color: #{color}"} x-show={"active === '#{color}'"} />
                </label>
              <% end %>
            </div>
          </div>
          <%= error_tag(f, :color) %>
          <p class="support">
            This color will help visually identify the project.
          </p>
        </div>
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
      </.form>
    </article>
    """
  end
end
