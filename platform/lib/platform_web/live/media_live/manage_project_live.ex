defmodule PlatformWeb.MediaLive.ManageProjectsLive do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Auditor
  alias Platform.Projects

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:projects, Projects.list_projects_for_user(assigns.current_user))
     |> assign_new(:changeset, fn -> changeset(socket |> assign(assigns)) end)}
  end

  def changeset(socket, attrs \\ %{}) do
    Material.change_media_project(
      socket.assigns.media,
      attrs,
      socket.assigns.current_user
    )
  end

  def handle_event("validate", %{"media" => params}, socket) do
    cs =
      changeset(socket, params)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:changeset, cs)}
  end

  def handle_event("save", %{"media" => params}, socket) do
    cs = changeset(socket, params)

    if cs.valid? do
      case Material.update_media_project_audited(
             socket.assigns.media,
             socket.assigns.current_user,
             params
           ) do
        {:ok, media} ->
          Auditor.log(
            :media_project_changed,
            %{
              media: media
            },
            socket
          )

          send(self(), {:project_changed, media})
          {:noreply, socket |> assign(:disabled, true)}

        {:error, %Ecto.Changeset{} = cs} ->
          {:noreply, assign(socket, :changeset, cs |> Map.put(:action, :validate))}
      end
    else
      {:noreply, assign(socket, :changeset, cs |> Map.put(:action, :validate))}
    end
  end

  def render(assigns) do
    ~H"""
    <article>
      <.form
        :let={f}
        for={@changeset}
        id="project-change"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="phx-form"
      >
        <div class="space-y-6">
          <div>
            <%= label(
              f,
              :project_id,
              "Project"
            ) %>
            <div phx-update="ignore" id={"project_select_#{@media.slug}"}>
              <%= select(
                f,
                :project_id,
                ["No Project": nil] ++ Enum.map(@projects, &{"#{&1.name}", &1.id}),
                data_descriptions:
                  Jason.encode!(
                    Enum.reduce(@projects, %{}, fn elem, acc ->
                      Map.put(acc, elem.id, elem.code)
                    end)
                  )
              ) %>
            </div>
            <%= error_tag(f, :project_id) %>
          </div>
          <%= submit(
            "Save",
            phx_disable_with: "Saving...",
            class: "button ~urge @high"
          ) %>
        </div>
      </.form>
    </article>
    """
  end
end
