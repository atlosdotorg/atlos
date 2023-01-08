defmodule PlatformWeb.NewLive.BasicInfoLive do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Material.Attribute
  alias Platform.Auditor
  alias Platform.Accounts

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_media()
     |> assign(:disabled, false)
     |> assign(:url_deconfliction, [])
     |> assign_changeset(%{"project_id" => assigns.project_id})}
  end

  defp assign_media(socket) do
    socket |> assign(:media, %Material.Media{})
  end

  defp assign_changeset(socket, params \\ %{}, opts \\ []) do
    cs = Material.change_media(socket.assigns.media, params, socket.assigns.current_user)

    cs =
      if Keyword.get(opts, :validate, false) do
        cs |> Map.put(:action, :validate)
      else
        cs
      end

    # If available, assign the URLs
    url_deconfliction =
      Ecto.Changeset.get_field(cs, :urls_parsed, "")
      |> Enum.map(fn url ->
        {url, Material.get_media_by_source_url(url)}
      end)

    socket
    |> assign(
      :changeset,
      cs
    )
    |> assign(
      :url_deconfliction,
      url_deconfliction
    )
  end

  def handle_event("validate", %{"media" => media_params}, socket) do
    # TODO: We don't currently do live validation because it causes the multiselect panel to jump around.
    # Given the time, it'd be nice to fix this.

    {:noreply, socket |> assign_changeset(media_params, validate: true)}
  end

  def handle_event("save", %{"media" => media_params}, socket) do
    case Material.create_media_audited(socket.assigns.current_user, media_params) do
      {:ok, media} ->
        # We log here, rather than in the context, because we have access to the socket.
        # TODO: We should do the audit logging inside the context. We just need to sort out
        # the socket issue.
        Auditor.log(:media_created, Map.merge(media_params, %{media_slug: media.slug}), socket)
        send(self(), {:media_created, media})

        {:noreply,
         socket
         |> assign(:disabled, true)
         # We assign a changeset to prevent their changes from flickering during submit
         |> assign(
           :changeset,
           Material.change_media(socket.assigns.media, media_params, socket.assigns.current_user)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset |> Map.put(:action, :validate))}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <.form
        :let={f}
        for={@changeset}
        id="media-form"
        phx-target={@myself}
        phx-submit="save"
        phx-change="validate"
        class="phx-form"
      >
        <div class="space-y-6">
          <div>
            <.edit_attribute
              attr={Attribute.get_attribute(:description)}
              form={f}
              media_slug="NEW"
              media={nil}
            />
            <p class="support">
              Try to be as descriptive as possible. You'll be able to change this later.
            </p>
          </div>

          <div>
            <.edit_attribute
              attr={Attribute.get_attribute(:sensitive)}
              form={f}
              media_slug="NEW"
              media={nil}
            />
          </div>

          <div>
            <.edit_attribute
              attr={Attribute.get_attribute(:type)}
              form={f}
              media_slug="NEW"
              media={nil}
            />
          </div>

          <% projects = Platform.Projects.list_projects_for_user(@current_user) %>
          <%= if not Enum.empty?(projects) do %>
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
                  ["No Project": nil] ++ Enum.map(projects, &{"#{&1.name}", &1.id}),
                  data_descriptions:
                    Jason.encode!(
                      Enum.reduce(projects, %{}, fn elem, acc ->
                        Map.put(acc, elem.id, elem.code)
                      end)
                    )
                ) %>
              </div>
              <%= error_tag(f, :project_id) %>
            </div>
          <% end %>

          <div class="flex flex-col gap-1">
            <label>Source Material <span class="badge ~neutral inline text-xs">Optional</span></label>
            <.interactive_urldrop
              form={f}
              id="urldrop"
              name={:urls}
              placeholder="Drop URLs here..."
              class="input-base"
            />
            <p class="support">Atlos will attempt to archive these URLs automatically.</p>
            <%= error_tag(f, :urls) %>
            <%= error_tag(f, :urls_parsed) %>
            <%= if not Enum.empty?(@url_deconfliction) do %>
              <div class="mt-4">
                <.multi_deconfliction_warning
                  url_media_pairs={@url_deconfliction}
                  current_user={@current_user}
                />
              </div>
            <% end %>
          </div>

          <div class="p-4 rounded bg-neutral-100 mt-2" x-data="{open: false}">
            <button
              type="button"
              class="text-button w-full block flex gap-1 items-center justify-between cursor-pointer transition-all"
              x-on:click="open = !open"
            >
              Additional attributes
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="currentColor"
                class="w-6 h-6"
                x-show="!open"
              >
                <path
                  fill-rule="evenodd"
                  d="M12 5.25a.75.75 0 01.75.75v5.25H18a.75.75 0 010 1.5h-5.25V18a.75.75 0 01-1.5 0v-5.25H6a.75.75 0 010-1.5h5.25V6a.75.75 0 01.75-.75z"
                  clip-rule="evenodd"
                />
              </svg>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="currentColor"
                class="w-6 h-6"
                x-show="open"
              >
                <path
                  fill-rule="evenodd"
                  d="M5.25 12a.75.75 0 01.75-.75h12a.75.75 0 010 1.5H6a.75.75 0 01-.75-.75z"
                  clip-rule="evenodd"
                />
              </svg>
            </button>
            <div class="space-y-6 mt-4" x-transition x-show="open">
              <hr />
              <div>
                <.edit_attribute
                  attr={Attribute.get_attribute(:equipment)}
                  form={f}
                  media_slug="NEW"
                  media={nil}
                  optional={true}
                />
              </div>

              <div>
                <.edit_attribute
                  attr={Attribute.get_attribute(:impact)}
                  form={f}
                  media_slug="NEW"
                  media={nil}
                  optional={true}
                />
              </div>

              <div>
                <.edit_attribute
                  attr={Attribute.get_attribute(:date)}
                  form={f}
                  media_slug="NEW"
                  media={nil}
                  optional={true}
                />
              </div>

              <div>
                <.edit_attribute
                  attr={Attribute.get_attribute(:general_location)}
                  form={f}
                  media_slug="NEW"
                  media={nil}
                  optional={true}
                />
              </div>

              <%= if Accounts.is_privileged(@current_user) do %>
                <div>
                  <.edit_attribute
                    attr={Attribute.get_attribute(:tags)}
                    form={f}
                    media_slug="NEW"
                    media={nil}
                    optional={true}
                  />
                </div>
              <% end %>
            </div>
          </div>

          <div class="md:flex gap-2 items-center justify-between">
            <%= submit("Create incident",
              phx_disable_with: "Saving...",
              class: "button ~urge @high",
              disabled: @disabled
            ) %>
            <p class="support text-neutral-600">You can upload media in the next step</p>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
