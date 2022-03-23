defmodule PlatformWeb.MediaLive.UploadVersionLive do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Utils

  def update(assigns, socket) do
    {:ok, socket |> assign(assigns) |> assign_version() |> assign_changeset() |> assign(:form_id, Utils.generate_random_sequence(10)) }
  end

  defp assign_version(socket) do
    socket |> assign(:version, %Material.MediaVersion{media: socket.assigns.media})
  end

  defp assign_changeset(socket) do
    socket |> assign(:changeset, Material.change_media_version(socket.assigns.version))
  end

  def render(assigns) do
    ~H"""
    <article>
      <.form
        let={f}
        for={@changeset}
        id={"media-upload-#{@form_id}"}
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        class="phx-form"
      >
        <div class="space-y-6">
          <div class="max-w-lg flex justify-center px-6 pt-5 pb-6 border-2 border-gray-300 border-dashed rounded-md">
            <div class="space-y-1 text-center">
              <svg xmlns="http://www.w3.org/2000/svg" aria-hidden="true" class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
              </svg>
              <div class="flex text-sm text-gray-600 justify-center">
                <label for="file-upload" class="relative cursor-pointer bg-white rounded-md font-medium !text-urge-600 hover:text-urge-500 focus-within:outline-none focus-within:ring-2 focus-within:ring-offset-2 focus-within:ring-urge-500">
                  <span>Upload a file</span>
                  <input id="file-upload" name="file-upload" type="file" class="sr-only">
                </label>
                <p class="pl-1 text-center">or drag and drop</p>
              </div>
              <p class="text-xs text-gray-500">PNG, JPG, GIF, MP4, HEIC, or AVI up to 250MB</p>
            </div>
          </div>
          <div>
            <%= label f, :source_url, "Where did this media come from?" %>
            <%= url_input f, :source_url, placeholder: "https://example.com/..." %>
            <p class="support">While the source URL is not required, it helps the community verify provenance and is strongly recommended.</p>
            <%= error_tag f, :source_url %>
          </div>
          <%= submit "Upload →", phx_disable_with: "Uploading...", class: "button ~urge @high", disabled: @changeset.changes == %{} %>
        </div>
      </.form>
    </article>
    """
  end
end
