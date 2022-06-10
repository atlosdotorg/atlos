defmodule PlatformWeb.AdminlandLive.ActivityFeedLive do
  use PlatformWeb, :live_component
  use Ecto.Schema
  import Ecto.Query

  alias Platform.Accounts
  alias Platform.Updates

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:query, fn -> nil end)
     |> assign_changeset()
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
      <div>
        <.card>
          <:header>
            <div class="flex flex-col md:flex-row gap-4 md:gap-8 justify-between">
              <div>
                <p class="sec-head">Activity Feed</p>
                <p class="sec-subhead">This is the latest activity on Atlos.</p>
              </div>
              <div class="flex-grow max-w-md">
                <.form
                  let={f}
                  for={@changeset}
                  as="query"
                  phx-change="change"
                  phx-submit="save"
                  phx-target={@myself}
                >
                  <div class="border border-gray-300 bg-white rounded-md px-3 py-2 shadow-sm focus-within:ring-1 focus-within:ring-urge-600 focus-within:border-urge-600">
                    <%= label(f, :query, "Search", class: "block text-xs font-medium text-gray-900") %>
                    <%= text_input(f, :query,
                      placeholder: "Enter a query...",
                      phx_debounce: "1000",
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
