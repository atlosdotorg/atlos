defmodule PlatformWeb.MediaLive.MergeVersionsLive do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Auditor
  alias Platform.Permissions

  def update(assigns, socket) do
    if Permissions.can_merge_media?(assigns.current_user, assigns.source) do
      {:ok,
       socket
       |> assign(assigns)
       |> assign_new(:destination, fn -> nil end)
       |> assign_new(:changeset, fn -> changeset(%{}, assigns.source) end)}
    else
      raise PlatformWeb.Errors.Unauthorized, "No permission"
    end
  end

  @types %{
    destination: :string
  }

  def changeset(params, source) do
    data = %{}

    {data, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> Ecto.Changeset.validate_required([:destination])
    |> validate_slug(:destination, source)
  end

  def validate_slug(changeset, field, source) when is_atom(field) do
    Ecto.Changeset.validate_change(changeset, field, fn field, value ->
      case value do
        nil ->
          []

        slug ->
          case Material.get_full_media_by_slug(slug) do
            nil ->
              [{field, "This incident doesn't seem to exist. Is the six-character correct?"}]

            media ->
              if media.id == source.id do
                [{field, "You cannot merge media into itself."}]
              else
                []
              end
          end
      end
    end)
  end

  def handle_event("validate", %{"merge" => params}, socket) do
    cs =
      changeset(params, socket.assigns.source)
      |> Map.put(:action, :validate)

    destination_code = Ecto.Changeset.get_field(cs, :destination)

    {:noreply,
     socket
     |> assign(:changeset, cs)
     |> assign(:destination, Material.get_full_media_by_slug(destination_code || ""))}
  end

  def handle_event("save", %{"merge" => params}, socket) do
    cs = changeset(params, socket.assigns.source)

    if cs.valid? do
      case Material.merge_media_versions_audited(
             socket.assigns.source,
             Material.get_full_media_by_slug(Ecto.Changeset.get_field(cs, :destination)),
             socket.assigns.current_user
           ) do
        {:ok, version} ->
          Auditor.log(
            :media_versions_merged,
            %{
              source: socket.assigns.source.slug,
              destination: Ecto.Changeset.get_field(cs, :destination)
            },
            socket
          )

          send(self(), {:merge_completed, version})
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
            <%= label(
              f,
              :destination,
              "What is the slug (code) of the incident to merge media into?"
            ) %>
            <%= text_input(f, :destination, placeholder: "E.g., 123456", phx_debounce: "250") %>
            <p class="support">
              Media from <%= @source.slug %> will be copied to this incident.
            </p>
            <%= error_tag(f, :destination) %>
          </div>
          <%= submit(
            "Merge",
            phx_disable_with: "Merging...",
            class: "button ~urge @high"
          ) %>
        </div>
      </.form>
    </article>
    """
  end
end
