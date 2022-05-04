defmodule PlatformWeb.MediaLive.LinkVersionLive do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Utils
  alias Platform.Auditor

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_version()
     |> assign_changeset()}
  end

  defp assign_version(socket) do
    socket |> assign(:version, %Material.MediaVersion{media: socket.assigns.media})
  end

  defp assign_changeset(socket) do
    socket |> assign(:changeset, Material.change_media_version(socket.assigns.version))
  end

  defp set_fixed_params(params, socket) do
    params
    |> Map.put("media_id", socket.assigns.media.id)
    |> Map.put("status", "pending")
    |> Map.put("upload_type", "direct")
  end

  def handle_event("validate", %{"media_version" => params}, socket) do
    params = params |> set_fixed_params(socket)

    changeset =
      socket.assigns.version
      |> Material.change_media_version(params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def handle_event("save", %{"media_version" => params}, socket) do
    params = params |> set_fixed_params(socket)

    changeset =
      socket.assigns.version
      |> Material.change_media_version(params)
      |> Map.put(:action, :validate)

    case Material.create_media_version_audited(
           socket.assigns.media,
           socket.assigns.current_user,
           params
         ) do
      {:ok, version} ->
        Auditor.log(
          :media_version_uploaded,
          Map.merge(params, %{media_slug: socket.assigns.media.slug}),
          socket
        )

        send(self(), {:version_created, version})
        {:noreply, socket |> assign(:disabled, true)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def render(assigns) do
    ~H"""
    <article>
      <.form
        let={f}
        for={@changeset}
        id="media-upload"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="phx-form"
      >
        <div class="space-y-6">
          <div>
            <%= label(f, :source_url, "What is the link to the video you would like to upload?") %>
            <%= url_input(f, :source_url, placeholder: "https://example.com/...") %>
            <p class="support">
              This might be a tweet, a Telegram message, or something else.
            </p>
            <%= error_tag(f, :source_url) %>
          </div>
          <%= submit("Publish to Atlos",
            phx_disable_with: "Publishing...",
            class: "button ~urge @high"
          ) %>
        </div>
      </.form>
    </article>
    """
  end
end
