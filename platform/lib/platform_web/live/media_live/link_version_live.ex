defmodule PlatformWeb.MediaLive.LinkVersionLive do
  use PlatformWeb, :live_component
  alias Platform.Material
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

  defp apply_changeset(version, params) do
    Material.change_media_version(version, params)
    |> Ecto.Changeset.validate_format(
      :source_url,
      ~r/(https:\/\/)(www.)?(youtube.com|twitter.com|youtu.be|t.co)/iu,
      message:
        "Only Twitter and YouTube links are currently supported. Should start with 'https://...'"
    )
  end

  def handle_event("validate", %{"media_version" => params}, socket) do
    params = params |> set_fixed_params(socket)

    changeset =
      socket.assigns.version
      |> apply_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  def handle_event("save", %{"media_version" => params}, socket) do
    params = params |> set_fixed_params(socket)

    changeset =
      socket.assigns.version
      |> apply_changeset(params)
      |> Map.put(:action, :validate)

    if changeset.valid? do
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

          # Start archival
          Task.start(fn -> Material.archive_media_version(version) end)

          # Wrap up
          send(self(), {:version_created, version})
          {:noreply, socket |> assign(:disabled, true)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :changeset, changeset)}
      end
    else
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
            <%= label(f, :source_url, "What is the link to the media you would like to upload?") %>
            <%= url_input(f, :source_url, placeholder: "https://example.com/...") %>
            <p class="support">
              We support automatic archiving from YouTube and Twitter. To upload media from other platforms, use manual uploading.
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
