defmodule PlatformWeb.MediaLive.CopyMediaLive do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Auditor
  alias Platform.Permissions
  alias Platform.Projects

  def update(assigns, socket) do
    if Permissions.can_copy_media?(assigns.current_user, assigns.source) do
      {:ok,
       socket
       |> assign(assigns)
       |> assign_new(:destination, fn -> nil end)
       |> assign(
         :project_options,
         Projects.list_editable_projects_for_user(assigns.current_user)
       )
       |> assign_new(:changeset, fn -> changeset(%{}, assigns.source) end)}
    else
      raise PlatformWeb.Errors.Unauthorized, "No permission"
    end
  end

  @types %{
    destination_project_id: :string
  }

  def changeset(params, source) do
    data = %{}

    {data, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.validate_required([:destination_project_id])
    |> validate_project_id(:destination_project_id, source)
  end

  def validate_project_id(changeset, field, source) when is_atom(field) do
    Ecto.Changeset.validate_change(changeset, field, fn field, value ->
      case value do
        nil ->
          []

        slug ->
          case Projects.get_project(slug) do
            nil ->
              [{field, "This project doesn't seem to exist."}]

            project ->
              []
          end
      end
    end)
  end

  def handle_event("validate", %{"merge" => params}, socket) do
    cs =
      changeset(params, socket.assigns.source)
      |> Map.put(:action, :validate)

    destination_code = Ecto.Changeset.get_field(cs, :destination_project_id)

    {:noreply,
     socket
     |> assign(:changeset, cs)
     |> assign(:destination, Projects.get_project(destination_code))}
  end

  def handle_event("save", %{"merge" => params}, socket) do
    cs = changeset(params, socket.assigns.source)

    if cs.valid? do
      case Material.copy_media_to_project_audited(
             socket.assigns.source,
             Projects.get_project(Ecto.Changeset.get_field(cs, :destination_project_id)),
             socket.assigns.current_user
           ) do
        {:ok, new_media} ->
          Auditor.log(
            :media_copied,
            %{
              source: socket.assigns.source.slug,
              destination: Ecto.Changeset.get_field(cs, :destination_project_id),
              destination_media_slug: new_media.slug
            },
            socket
          )

          send(self(), {:copy_completed, new_media})
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
        id="merge-assistant"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="phx-form"
        as={:merge}
      >
        <div class="space-y-6">
          <div>
            <div>
              <%= label(
                f,
                :destination_project_id,
                "Copy to Project"
              ) %>
              <div phx-update="ignore" id={"project_select_#{@source.slug}"}>
                <%= select(
                  f,
                  :destination_project_id,
                  Enum.map(@project_options, &{"#{&1.name}", &1.id}),
                  data_descriptions:
                    Jason.encode!(
                      Enum.reduce(@project_options, %{}, fn elem, acc ->
                        Map.put(acc, elem.id, elem.code)
                      end)
                    )
                ) %>
              </div>
              <%= error_tag(f, :destination_project_id) %>
            </div>
          </div>
          <%= submit(
            "Copy",
            phx_disable_with: "Copying...",
            class: "button ~urge @high"
          ) %>
        </div>
      </.form>
    </article>
    """
  end
end
