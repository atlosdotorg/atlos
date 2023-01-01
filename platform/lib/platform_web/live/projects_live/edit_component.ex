defmodule PlatformWeb.ProjectsLive.EditComponent do
  use PlatformWeb, :live_component

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
            send(self(), {:close, project})
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
          <%= label(f, :color) %>
          <%= color_input(f, :color) %>
          <%= error_tag(f, :color) %>
          <p class="support">
            This color will help visually identify the project.
          </p>
        </div>
        <div>
          <%= submit("Save", class: "button ~urge @high") %>
          <button phx-click="close" class="button ~neutral" type="button" phx-target={@myself}>
            Cancel
          </button>
        </div>
      </.form>
    </article>
    """
  end
end
