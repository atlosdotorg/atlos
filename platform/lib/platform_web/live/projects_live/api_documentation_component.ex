defmodule PlatformWeb.ProjectLive.APIDoc do
  use PlatformWeb, :live_component

  alias Platform.Projects
  alias Platform.Material.Attribute

  def update(%{project: project} = assigns, socket) do
    attributes = Platform.Material.Attribute.active_attributes(project: project)
    attribute_labels = Map.new(attributes, &{&1.name, &1.label})
    grouped_attributes = group_attributes(attributes, project)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:grouped_attributes, grouped_attributes)
     |> assign(:attribute_labels, attribute_labels)
     |> assign(:project, project)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col lg:flex-row gap-4 pt-8 w-full">
      <div class="mb-4 lg:w-[20rem] lg:mr-16">
        <p class="sec-head text-xl">API Details</p>
        <p class="sec-subhead">
          The Atlos API uses API-specific identifers, rather than interface names, to refer to attributes, metadata, and even the project itself. Learn more in our
          <u>
            <a class="text-blue-800" href="https://docs.atlos.org/technical/api/">
              API documentation.
            </a>
          </u>
        </p>
      </div>
      <section class="flex-1 flex flex-col mb-8 grow">
        <div class="flow-root">
          <div class="pb-4">
            <div class="inline-block min-w-full">
              <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8 grow">
                <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
                  <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 sm:rounded-lg">
                    <div class="min-w-full divide-y divide-gray-300">
                      <div class="px-6 bg-gray-50">
                        <div class="flex justify-between items-center">
                          <div
                            scope="col"
                            class="py-4 text-left text-sm font-semibold text-gray-900 flex-1"
                          >
                            Interface Name
                          </div>
                          <div
                            scope="col"
                            class="px-3 py-4 text-left text-sm font-semibold text-gray-900 flex-1"
                          >
                            API Identifier
                          </div>
                        </div>
                      </div>
                      <div class="bg-white divide-y divide-gray-200">
                        <%= for {group, attributes} <- @grouped_attributes do %>
                          <section class="rounded-[0px]">
                            <div
                              class={"px-6 flex flex-col #{if group != :core_and_unassigned, do: "pb-1 pt-5"}"}
                              style={
                                if group != :core_and_unassigned,
                                  do: "border-left: 4px solid #{get_group_color(group)};"
                              }
                            >
                              <%= if group != :core_and_unassigned do %>
                                <div class="border-b border-dashed pb-3 border-gray-200 flex">
                                  <p class="font-medium text-sm flex-1">
                                    <span style={"color: #{get_group_color(group)}; filter: brightness(65%);"}>
                                      <%= cond do %>
                                        <% group == :metadata -> %>
                                          Metadata
                                        <% group == :project -> %>
                                          Project
                                        <% true -> %>
                                          <%= group.name %>
                                      <% end %>
                                    </span>
                                  </p>
                                  <p class="text-sm text-gray-500 flex-1">
                                    <%= cond do %>
                                      <% group == :metadata -> %>
                                        Use the API to access or update incident metadata in the same way as other attributes.
                                      <% group == :project -> %>
                                        Use this identifier to refer to this project in the API.
                                      <% true -> %>
                                        <%= group.description %>
                                    <% end %>
                                  </p>
                                </div>
                              <% end %>
                              <div class="divide-y divide-dashed divide-gray-200">
                                <%= for attribute <- attributes do %>
                                  <div class="py-1.5">
                                    <div class="flex justify-between items-center">
                                      <div class="text-sm flex-1 font-base text-gray-900">
                                        <%= if attribute == @project,
                                          do: attribute.name,
                                          else: attribute.label %>
                                      </div>
                                      <div class="px-3 flex-1 text-sm text-gray-500 font-mono">
                                        <div x-data="{pulse: false}">
                                          <button
                                            class="chip netural font-mono chip ~neutral inline-block flex gap-1 items-center self-start break-all hover:bg-neutral-200 transition-all"
                                            x-bind:class="pulse ? 'animate-ping' : ''"
                                            data-tooltip="Copy information to your clipboard"
                                            type="button"
                                            x-on:click={"window.setClipboard(#{Jason.encode!(attribute.name)}); pulse = true; setTimeout(() => pulse = false, 500)"}
                                          >
                                            <%= if attribute == @project,
                                              do: attribute.id,
                                              else: attribute.name %>
                                          </button>
                                        </div>
                                      </div>
                                    </div>
                                  </div>
                                <% end %>
                              </div>
                            </div>
                          </section>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp group_attributes(attributes, project) do
    core_attributes = Enum.filter(attributes, &(is_atom(&1.name) and &1.pane != :metadata))

    ## Sort metadata alphabetically, because it doesn't have a custom order
    metadata_attributes =
      Enum.sort_by(Enum.filter(attributes, &(&1.pane == :metadata)), & &1.label)

    custom_attributes = Enum.reject(attributes, &(is_atom(&1.name) or &1.pane == :metadata))

    groups = project.attribute_groups || []

    grouped =
      Enum.map(groups, fn group ->
        attributes = Enum.filter(custom_attributes, &(&1.name in group.member_ids))
        {group, attributes}
      end)

    unassigned_attributes =
      Enum.reject(custom_attributes, fn attr ->
        Enum.any?(groups, &(attr.name in &1.member_ids))
      end)

    [
      {:core_and_unassigned, core_attributes ++ unassigned_attributes}
    ] ++
      grouped ++
      [
        {:metadata, metadata_attributes}
      ] ++
      [
        {:project, [project]}
      ]
  end

  defp get_group_color(group) do
    cond do
      group == :metadata ->
        "#f87171"

      group == :project ->
        "#000000"

      true ->
        group.color
    end
  end
end
