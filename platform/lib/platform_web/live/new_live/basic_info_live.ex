defmodule PlatformWeb.NewLive.BasicInfoLive do
  use PlatformWeb, :live_component
  alias Platform.Material
  alias Platform.Material.Attribute
  alias Platform.Auditor
  alias Platform.Permissions
  alias Platform.Projects

  def update(assigns, socket) do
    dbg("input is running")

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       :project_options,
       Projects.list_projects_for_user(assigns.current_user)
       |> Enum.filter(&Permissions.can_add_media_to_project?(assigns.current_user, &1))
     )
     |> assign(:disabled, false)
     |> assign(:url_deconfliction, [])
     |> assign_changeset(%{"project_id" => assigns.project_id})}
  end

  defp assign_changeset(socket, params, opts \\ []) do
    # Also assigns the @project and @media

    project_id =
      Map.get(params, "project_id") || Enum.at(socket.assigns.project_options, 0, %{id: nil}).id

    project = Platform.Projects.get_project(project_id)
    media = %Material.Media{project_id: project_id, project: project}

    cs = Material.change_media(media, params, socket.assigns.current_user)

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
        {url, Material.get_media_by_source_url(url, for_user: socket.assigns.current_user)}
      end)

    # If available, assign the project

    socket
    |> assign(
      :changeset,
      cs
    )
    |> assign(
      :url_deconfliction,
      url_deconfliction
    )
    |> assign(
      :project,
      project
    )
    |> assign(
      :media,
      media
    )
    |> assign(:form, to_form(cs))
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
        cs = changeset |> Map.put(:action, :validate)
        {:noreply, assign(socket, :changeset, cs) |> assign(:form, to_form(cs))}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <%= if Enum.empty?(@project_options) do %>
        <div class="flex flex-col gap-4 items-center justify-around">
          <div class="flex flex-col gap-2 items-center justify-around">
            <Heroicons.archive_box class="w-12 h-12 text-neutral-500" />
            <h2 class="text-md font-medium">No Projects</h2>
            <p class="text-sm text-neutral-500 text-center">
              You don't have any projects yet. You'll need to create one before you can add media.
            </p>
            <.link href="/projects/new" class="button ~urge @high">Create a Project</.link>
          </div>
        </div>
      <% else %>
        <.form
          for={@form}
          id="media-form"
          phx-target={@myself}
          phx-submit="save"
          phx-change="validate"
          class="phx-form"
        >
          <div class="space-y-6">
            <%= if not Enum.empty?(@project_options) do %>
              <div>
                <%= label(
                  @form,
                  :project_id,
                  "Project"
                ) %>
                <div phx-update="ignore" id={"project_select_#{@media.slug}"}>
                  <%= select(
                    @form,
                    :project_id,
                    Enum.map(@project_options, &{"#{&1.name}", &1.id}),
                    data_descriptions:
                      Jason.encode!(
                        Enum.reduce(@project_options, %{}, fn elem, acc ->
                          Map.put(acc, elem.id, elem.code)
                        end)
                      )
                  ) %>
                </div>
                <%= error_tag(@form, :project_id) %>
              </div>
            <% end %>

            <div>
              <.edit_attributes
                attrs={[Attribute.get_attribute(:description)]}
                form={@form}
                media_slug="NEW"
                media={nil}
                optional={false}
              />
            </div>

            <div>
              <.edit_attributes
                attrs={[Attribute.get_attribute(:sensitive)]}
                form={@form}
                media_slug="NEW"
                media={nil}
                optional={false}
              />
            </div>

            <div class="flex flex-col gap-1">
              <label>
                Source Material <span class="badge ~neutral inline text-xs">Optional</span>
              </label>
              <.interactive_urldrop
                form={@form}
                id="urldrop"
                name={:urls}
                placeholder="Drop URLs here..."
                class="input-base"
              />
              <p class="support">Atlos will attempt to archive these URLs automatically.</p>
              <%= error_tag(@form, :urls) %>
              <%= error_tag(@form, :urls_parsed) %>
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
                  <.edit_attributes
                    attrs={[Attribute.get_attribute(:date)]}
                    form={@form}
                    media_slug="NEW"
                    media={nil}
                    optional={true}
                  />
                </div>

                <%= if Permissions.can_edit_media?(@current_user, @media, Attribute.get_attribute(:tags, project: @project)) do %>
                  <div>
                    <.edit_attributes
                      attrs={[Attribute.get_attribute(:tags, project: @project)]}
                      form={@form}
                      media_slug="NEW"
                      media={nil}
                      optional={true}
                    />
                  </div>
                <% end %>

                <%= if not is_nil(@project) and not Enum.empty?(@project.attributes) do %>
                  <hr />
                  <div id={"project-attributes-#{@project.id}"}>
                    <.edit_attributes
                      attrs={
                        @project.attributes
                        |> Enum.map(&Platform.Projects.ProjectAttribute.to_attribute/1)
                      }
                      form={@form}
                      media_slug={@project.id}
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
      <% end %>
    </div>
    """
  end
end
