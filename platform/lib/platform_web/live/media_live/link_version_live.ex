defmodule PlatformWeb.MediaLive.LinkVersionLive do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Auditor

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_version()
     |> assign_source_url_duplicate(%{})
     |> assign_changeset()}
  end

  defp assign_version(socket) do
    socket |> assign(:version, %Material.MediaVersion{media: socket.assigns.media})
  end

  defp assign_changeset(socket) do
    socket |> assign(:changeset, Material.change_media_version(socket.assigns.version))
  end

  defp assign_source_url_duplicate(socket, params) do
    source_url = Map.get(params, "source_url", "")

    if String.length(source_url) > 0 do
      socket
      |> assign(
        :url_duplicate_of,
        Material.get_media_by_source_url(source_url)
        |> Enum.filter(&Material.Media.can_user_view(&1, socket.assigns.current_user))
        |> Enum.filter(&(&1.id != socket.assigns.media.id))
      )
    else
      socket |> assign(:url_duplicate_of, [])
    end
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
      ~r/(https:\/\/)(www.)?(youtube.com|twitter.com|youtu.be|t.co|tiktok.com)/iu,
      message:
        "Only videos on Twitter, YouTube, and TikTok are currently supported. Should start with 'https://...'"
    )
  end

  def handle_event("validate", %{"media_version" => params}, socket) do
    params = params |> set_fixed_params(socket)

    changeset =
      socket.assigns.version
      |> apply_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset) |> assign_source_url_duplicate(params)}
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
          Material.archive_media_version(version)

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
            <%= url_input(f, :source_url, placeholder: "https://twitter.com/...", phx_debounce: "250") %>
            <p class="support">
              We support automatically archiving <strong>videos</strong>
              from YouTube, Twitter, and TikTok. To upload from other platforms, or to upload images, use manual uploading.
            </p>
            <%= error_tag(f, :source_url) %>
            <%= if length(@url_duplicate_of) > 0 do %>
              <.deconfliction_warning duplicates={@url_duplicate_of} current_user={@current_user} />
            <% end %>
          </div>
          <div class="flex flex-col sm:flex-row gap-4 justify-between sm:items-center">
            <%= submit(
              "Publish to Atlos",
              phx_disable_with: "Uploading...",
              class: "button ~urge @high"
            ) %>
            <a href={"/incidents/#{@media.slug}/"} class="text-button text-sm text-right">
              Or skip media upload
              <span class="text-gray-500 font-normal block text-xs">
                You can upload media later
              </span>
            </a>
          </div>
        </div>
      </.form>
    </article>
    """
  end
end
