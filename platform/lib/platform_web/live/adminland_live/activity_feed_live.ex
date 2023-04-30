defmodule PlatformWeb.AdminlandLive.ActivityFeedLive do
  use PlatformWeb, :live_component
  use Ecto.Schema

  alias Platform.Updates

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:query, fn -> nil end)
     |> assign_changeset()
     |> assign_statistics()
     |> perform_search()}
  end

  defp assign_changeset(socket, params \\ %{}) do
    socket
    |> assign(
      :changeset,
      {%{}, %{query: :string}}
      |> Ecto.Changeset.cast(params, [:query])
      |> Ecto.Changeset.validate_length(:query, max: 240)
    )
  end

  defp assign_statistics(socket, filter \\ fn _ -> true end) do
    recent_updates =
      Updates.list_updates(inserted_after: NaiveDateTime.add(NaiveDateTime.utc_now(), -14, :day))
      |> Enum.filter(filter)

    socket
    |> assign(:projects, recent_updates |> Enum.map(& &1.media.project) |> Enum.uniq_by(& &1.id))
    |> assign(
      :active_projects_count,
      recent_updates |> Enum.map(& &1.media.project_id) |> Enum.uniq() |> length()
    )
    |> assign(
      :active_users_count,
      recent_updates |> Enum.map(& &1.user_id) |> Enum.uniq() |> length()
    )
    |> assign(
      :active_incidents_count,
      recent_updates |> Enum.map(& &1.media_id) |> Enum.uniq() |> length()
    )
    |> assign(:recent_updates_count, length(recent_updates))
  end

  defp perform_search(socket, extend \\ [], opts \\ []) do
    result =
      Updates.text_search(Ecto.Changeset.get_field(socket.assigns.changeset, :query))
      |> Updates.query_updates_paginated(opts)

    socket |> assign(:result, result) |> assign(:updates, result.entries ++ extend)
  end

  def handle_event("validate", params, socket) do
    handle_event("save", params, socket)
  end

  def handle_event("change", params, socket) do
    handle_event("save", params, socket)
  end

  def handle_event("save", %{"query" => query}, socket) do
    {:noreply, socket |> assign(:query, query) |> assign_changeset(query) |> perform_search()}
  end

  def handle_event("load_more", _params, socket) do
    cursor_after = socket.assigns.result.metadata.after

    {:noreply, socket |> perform_search(socket.assigns.updates, after: cursor_after)}
  end

  def render(assigns) do
    ~H"""
    <section class="max-w-3xl mx-auto">
      <div class="flex flex-col gap-16">
        <.card>
          <:header>
            <p class="sec-head">Statistics</p>
            <p class="sec-subhead">Usage over the past two weeks.</p>
          </:header>
          <dl class="mx-auto grid grid-cols-1 gap-px bg-gray-900/5 sm:grid-cols-2 lg:grid-cols-4 -m-5">
            <div class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-2 bg-white px-4 py-10 sm:px-6 xl:px-8">
              <dt class="text-sm font-medium leading-6 text-gray-500">Active Projects</dt>
              <dd class="w-full flex-none text-3xl font-medium leading-10 tracking-tight text-gray-900">
                <%= Formatter.format_number(@active_projects_count) %>
              </dd>
            </div>
            <div class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-2 bg-white px-4 py-10 sm:px-6 xl:px-8">
              <dt class="text-sm font-medium leading-6 text-gray-500">Active Users</dt>
              <dd class="w-full flex-none text-3xl font-medium leading-10 tracking-tight text-gray-900">
                <%= Formatter.format_number(@active_users_count) %>
              </dd>
            </div>
            <div class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-2 bg-white px-4 py-10 sm:px-6 xl:px-8">
              <dt class="text-sm font-medium leading-6 text-gray-500">Active Incidents</dt>
              <dd class="w-full flex-none text-3xl font-medium leading-10 tracking-tight text-gray-900">
                <%= Formatter.format_number(@active_incidents_count) %>
              </dd>
            </div>
            <div class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-2 bg-white px-4 py-10 sm:px-6 xl:px-8">
              <dt class="text-sm font-medium leading-6 text-gray-500">Recent Updates</dt>
              <dd class="w-full flex-none text-3xl font-medium leading-10 tracking-tight text-gray-900">
                <%= Formatter.format_number(@recent_updates_count) %>
              </dd>
            </div>
          </dl>
        </.card>
        <.card>
          <:header>
            <p class="sec-head">Projects</p>
            <p class="sec-subhead">Projects with activity in the last two weeks.</p>
          </:header>
          <div class="grid grid-cols-1 gap-8 md:grid-cols-2">
            <%= for project <- @projects do %>
              <div>
                <.project_card project={project} />
                <hr class="sep h-2" />
                <.user_stack users={Platform.Projects.get_project_users(project)} />
              </div>
            <% end %>
          </div>
        </.card>
        <.card>
          <:header>
            <div class="flex flex-col md:flex-row gap-4 md:gap-8 justify-between">
              <div>
                <p class="sec-head">Activity Feed</p>
                <p class="sec-subhead">This is the latest activity on Atlos.</p>
              </div>
              <div class="flex-grow max-w-md">
                <.form
                  :let={f}
                  for={@changeset}
                  as={:query}
                  phx-change="change"
                  phx-submit="save"
                  phx-target={@myself}
                >
                  <div class="border border-gray-300 bg-white rounded-md px-3 py-2 shadow-sm focus-within:ring-1 focus-within:ring-urge-600 focus-within:border-urge-600">
                    <%= label(f, :query, "Search", class: "block text-xs font-medium text-gray-900") %>
                    <%= text_input(f, :query,
                      placeholder: "Enter a query...",
                      phx_debounce: "500",
                      class:
                        "block w-full border-0 p-0 text-gray-900 placeholder-gray-500 focus:ring-0 sm:text-sm"
                    ) %>
                  </div>
                  <%= error_tag(f, :query) %>
                </.form>
              </div>
            </div>
          </:header>
          <.live_component
            module={PlatformWeb.UpdatesLive.UpdateFeed}
            updates={@updates}
            current_user={@current_user}
            reverse={true}
            show_media={true}
            show_final_line={false}
            ignore_permissions={true}
            id="adminland-updates-feed"
          />
          <div class="mx-auto mt-8 text-center text-xs">
            <%= if !is_nil(@result.metadata.after) do %>
              <button
                type="button"
                class="text-button"
                phx-click="load_more"
                phx-target={@myself}
                phx-disable-with="Loading..."
              >
                Load More
              </button>
            <% end %>
          </div>
        </.card>
      </div>
    </section>
    """
  end
end
