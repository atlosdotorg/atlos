defmodule PlatformWeb.MediaLive.Index do
  use PlatformWeb, :live_view
  alias Platform.Material
  alias Platform.Material.Attribute

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Incidents")}
  end

  def handle_params(params, _uri, socket) do
    changeset = Material.MediaSearch.changeset(params)

    display =
      Ecto.Changeset.get_field(
        changeset,
        :display,
        socket.assigns.current_user.active_incidents_tab
      )

    if not Enum.member?(["map", "cards", "table"], display) do
      raise PlatformWeb.Errors.NotFound, "Display type not found"
    end

    # Update the user's prefered incident display, if necessary
    if socket.assigns.current_user.active_incidents_tab != display do
      Platform.Accounts.update_user_preferences(socket.assigns.current_user, %{
        active_incidents_tab: display
      })
    end

    # Pull cursor information from params
    before_cursor = params["bc"]
    after_cursor = params["ac"]
    pagination_index = (params["pi"] || "0") |> String.to_integer()

    search_keywords = [
      limit: if(display == "map", do: 100_000, else: 50),
      hydrate: display != "map"
    ]

    search_keywords =
      if not is_nil(before_cursor) and not (String.length(before_cursor) == 0) do
        Keyword.put(search_keywords, :before, before_cursor)
      else
        search_keywords
      end

    search_keywords =
      if not is_nil(after_cursor) and not (String.length(after_cursor) == 0) do
        Keyword.put(search_keywords, :after, after_cursor)
      else
        search_keywords
      end

    results =
      search_media(
        socket,
        changeset,
        # Ideally we would put these params in search_media, but since this is map-specific logic, it'll only be called here (it's not possible to "load more" on the map)
        search_keywords
      )

    active_project = Platform.Projects.get_project(params["project_id"])

    {:noreply,
     socket
     |> assign(
       :changeset,
       changeset
     )
     |> assign(:display, display)
     |> assign(:full_width, display == "table")
     |> assign(:query_params, params)
     |> assign(:before_cursor, before_cursor)
     |> assign(:after_cursor, after_cursor)
     |> assign(:active_project, active_project)
     |> assign(:results, results)
     |> assign(:myself, self())
     |> assign(:pagination_index, pagination_index)
     |> assign(:editing, nil)
     |> assign(:media, results.entries)
     |> assign(
       :attributes,
       Attribute.active_attributes(project: active_project) |> Enum.filter(&is_nil(&1.parent))
     )
     |> then(fn s ->
       if display == "table",
         do:
           assign(
             s,
             :source_cols,
             Enum.max(results.entries |> Enum.map(&length(&1.versions)), &>=/2, fn -> 0 end)
           ),
         else: s
     end)}
  end

  defp search_media(socket, c, pagination_opts) do
    {query, pagination_options} = Material.MediaSearch.search_query(c)

    query
    |> Material.MediaSearch.filter_viewable(socket.assigns.current_user)
    |> Material.query_media_paginated(
      Keyword.merge(Keyword.merge(pagination_options, pagination_opts),
        for_user: socket.assigns.current_user
      )
    )
  end

  def handle_event("validate", params, socket) do
    handle_event("save", params, socket)
  end

  def handle_event("save", %{"search" => params}, socket) do
    # Also reset the pagination index, since we're doing a new search
    merged_params =
      Map.merge(socket.assigns.query_params, params)
      |> Map.delete("bc")
      |> Map.delete("ac")
      |> Map.delete("pi")

    {:noreply, socket |> push_patch(to: Routes.live_path(socket, __MODULE__, merged_params))}
  end

  def handle_event(
        "edit_attribute",
        %{"attribute" => attr_name, "media-id" => media_id} = _params,
        socket
      ) do
    {id, ""} = Integer.parse(media_id)

    {:noreply,
     socket
     |> assign(
       :editing,
       {Enum.find(socket.assigns.media, &(&1.id == id)), attr_name}
     )}
  end

  def handle_info(
        {:end_attribute_edit, updated_media},
        socket
      ) do
    if is_nil(updated_media) do
      {:noreply, socket |> assign(:editing, nil)}
    else
      {:noreply,
       socket
       |> assign(:editing, nil)
       |> assign(
         :media,
         Enum.map(socket.assigns.media, fn m ->
           if m.id == updated_media.id, do: updated_media, else: m
         end)
       )
       |> put_flash(:info, "Your changes were applied successfully.")}
    end
  end
end
