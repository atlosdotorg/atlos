defmodule PlatformWeb.NewLive.NewComponent do
  use PlatformWeb, :live_component

  alias Platform.Material
  alias Platform.Material.Attribute
  alias Platform.Auditor
  alias Platform.Permissions
  alias Platform.Projects

  def update(assigns, socket) do
    active_project_membership =
      Platform.Accounts.get_user!(assigns.current_user.id).active_project_membership

    project_id =
      if is_nil(active_project_membership),
        do: nil,
        else: active_project_membership.project_id

    {:ok,
     socket
     |> assign(assigns)
     # We do this so that we rerender the project selector on page changes
     |> assign(:path_hash, :crypto.hash(:md5, assigns.path) |> Base.encode16())
     |> assign(
       :project_options,
       Projects.list_editable_projects_for_user(assigns.current_user)
     )
     |> assign(:disabled, false)
     |> assign(:url_deconfliction, [])
     |> assign_changeset(%{"project_id" => project_id})}
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

    {:noreply, socket |> assign_changeset(media_params)}
  end

  def handle_event("save", %{"media" => media_params}, socket) do
    if socket.assigns.disabled do
      {:noreply, socket}
    else
      case Material.create_media_audited(socket.assigns.current_user, media_params) do
        {:ok, media} ->
          # We log here, rather than in the context, because we have access to the socket.
          # TODO: We should do the audit logging inside the context. We just need to sort out
          # the socket issue.
          Auditor.log(:media_created, Map.merge(media_params, %{media_slug: media.slug}), socket)

          {:noreply,
           socket
           |> assign(:disabled, true)
           # We assign a changeset to prevent their changes from flickering during submit
           |> assign(
             :changeset,
             Material.change_media(
               socket.assigns.media,
               media_params,
               socket.assigns.current_user
             )
           )
           |> push_redirect(to: "/incidents/#{media.slug}")}

        {:error, %Ecto.Changeset{} = changeset} ->
          cs = changeset |> Map.put(:action, :validate)
          {:noreply, assign(socket, :changeset, cs) |> assign(:form, to_form(cs))}
      end
    end
  end

  def render(assigns) do
    ~H"""
    <div
      x-data="{
      // Active if the URL fragment is #new
      active: window.location.hash === '#new',
      setActive(val) {
        if (!val && document.elementContainsActiveUnsavedForms($refs.base)) {
          if (confirm('You have unsaved changes. Are you sure you want to exit?')) {
            this.active = val
          }
        } else {
          this.active = val
        }

        if (this.active) {
          window.stopBodyScroll()
        } else {
          window.resumeBodyScroll()
        }
      }
    }"
      x-init="() => {
        window.openNewIncidentDialog = () => {
          setActive(true)
        };
      }"
      id="globalcreate"
      class="w-full flex flex-col items-center"
      x-on:keydown.escape.window.prevent="setActive(false)"
      x-on:keydown.ctrl.i.window.prevent="setActive(!active)"
      x-on:keydown.meta.i.window.prevent="setActive(!active)"
      x-ref="base"
    >
      <button type="button" x-on:click="setActive(true)" class="w-full" id="new-incident-open-button">
        <%= render_slot(@inner_block) %>
      </button>
      <article x-cloak x-ref="body">
        <div
          x-bind:class="active ? 'fixed z-10 w-screen h-screen' : ''"
          role="dialog"
          aria-modal="true"
        >
          <div
            class="fixed inset-0 bg-neutral-600 bg-opacity-25"
            x-show="active"
            x-transition.opacity
          />
          <div
            class="fixed inset-0 z-10 md:ml-14 w-screen overflow-y-auto p-4 sm:p-6 md:p-20"
            x-transition
            x-show="active"
          >
            <div
              class="mx-auto max-w-xl lg:max-w-2xl divide-y transform overflow-hidden rounded-xl bg-white shadow-2xl ring-1 ring-black ring-opacity-5"
              x-on:click.outside="setActive(false)"
              data-blocks-body-scroll="true"
            >
              <div class="flex">
                <h2 class="font-medium text-xl p-4">New Incident</h2>
              </div>
              <%= if Enum.empty?(@project_options) do %>
                <div class="flex flex-col gap-4 items-center justify-around p-4">
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
                  class="phx-form divide-y"
                >
                  <div class="space-y-6 p-4">
                    <%= if not Enum.empty?(@project_options) do %>
                      <div>
                        <%= label(
                          @form,
                          :project_id,
                          "Project"
                        ) %>
                        <div phx-update="ignore" id={"project_selector_#{@path_hash}"}>
                          <%= select(
                            @form,
                            :project_id,
                            Enum.map(@project_options, &{"#{&1.name}", &1.id}),
                            data_descriptions:
                              Jason.encode!(
                                Enum.reduce(@project_options, %{}, fn elem, acc ->
                                  Map.put(acc, elem.id, elem.code)
                                end)
                              ),
                            id: "new_incident_project_selector"
                          ) %>
                        </div>
                        <%= error_tag(@form, :project_id) %>
                      </div>
                    <% end %>

                    <div x-effect="
                      if (active && !document.activeElement.isSameNode(document.getElementById('media_attr_description'))) {
                        // We need to wait for the input to be visible before we can focus it.
                        setTimeout(() => { document.getElementById('media_attr_description').focus(); document.getElementById('media_attr_description').select() }, 10)
                      }
                    ">
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
                  </div>

                  <div class="p-4" x-data="{open: false}">
                    <button
                      type="button"
                      class="text-button w-full block flex gap-1 items-center justify-between cursor-pointer transition-all text-sm"
                      x-on:click="open = !open"
                    >
                      Add additional information
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

                  <div class="md:flex gap-2 items-center justify-between p-4">
                    <%= submit("Create incident",
                      phx_disable_with: "Saving...",
                      class: "button ~urge @high",
                      disabled: @disabled
                    ) %>
                    <p class="support text-neutral-500">You will be redirected to the incident</p>
                  </div>
                </.form>
              <% end %>
            </div>
          </div>
        </div>
      </article>
    </div>
    """
  end
end
