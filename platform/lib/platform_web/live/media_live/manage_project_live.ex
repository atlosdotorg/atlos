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

    # Require that the project is changed
    cs =
      cs
      |> then(fn c ->
        if socket.assigns.media.project_id ==
             Ecto.Changeset.get_field(c, :project_id) do
          Ecto.Changeset.add_error(
            c,
            :project_id,
            "To change the project, you must select a different project than the current one."
          )
        else
          c
        end
      end)

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

          send(self(), {:project_change_complete, media})
          {:noreply, socket |> assign(:disabled, true)}

        {:error, %Ecto.Changeset{} = cs} ->
          {:noreply, assign(socket, :changeset, cs |> Map.put(:action, :validate))}
      end
    else
      {:noreply, assign(socket, :changeset, cs |> Map.put(:action, :validate))}
    end
  end

  def handle_event("close_modal", _params, socket) do
    send(self(), {:project_change_complete, nil})
    {:noreply, socket}
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
          <%= if not is_nil(@media.project) do %>
            <div class="rounded-md bg-blue-50 p-4 mb-4">
              <div class="flex">
                <div class="flex-shrink-0">
                  <Heroicons.information_circle mini class="h-5 w-5 text-blue-600" />
                </div>
                <div class="ml-3 prose">
                  <p class="text-sm text-blue-700">
                    <span class="font-medium">
                      All project-specific attributes will be archived and not visible when you change this incident's project.
                    </span>
                    They can be recovered by moving the incident back into this project. These attributes are: <%= @media.project.attributes
                    |> Enum.map(& &1.name)
                    |> Enum.join(", ") %>.
                  </p>
                </div>
              </div>
            </div>
          <% end %>
          <div>
            <%= label(
              f,
              :project_id,
              "Change Project"
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
