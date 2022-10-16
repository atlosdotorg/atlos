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
    display = Ecto.Changeset.get_field(changeset, :display, "map")

    results =
      search_media(socket, changeset,
        # Ideally we would put these params in search_media, but since this is map-specific logic, it'll only be called here (it's not possible to "load more" on the map)
        limit: if(display == "map", do: 100_000, else: 50),
        hydrate: display != "map"
      )

    {:noreply,
     socket
     |> assign(
       :changeset,
       changeset
     )
     |> assign(:display, display)
     |> assign(:full_width, display == "table")
     |> assign(:query_params, params)
     |> assign(:results, results)
     |> assign(:myself, self())
     |> assign(:editing, nil)
     |> assign(:media, results.entries)
     |> assign(:attributes, Attribute.active_attributes() |> Enum.filter(&is_nil(&1.parent)))
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

  defp search_media(socket, c, pagination_opts \\ []) do
    {query, pagination_options} = Material.MediaSearch.search_query(c)

    query
    |> Material.MediaSearch.filter_viewable(socket.assigns.current_user)
    |> Material.query_media_paginated(
      Keyword.merge(Keyword.merge(pagination_options, pagination_opts),
        for_user: socket.assigns.current_user
      )
    )
  end

  def handle_event("load_more", _params, socket) do
    cursor_after = socket.assigns.results.metadata.after

    results =
      search_media(socket, Material.MediaSearch.changeset(socket.assigns.query_params),
        after: cursor_after
      )

    new_socket =
      socket
      |> assign(:results, results)
      |> assign(:media, socket.assigns.media ++ results.entries)

    {:noreply, new_socket}
  end

  def handle_event("validate", params, socket) do
    handle_event("save", params, socket)
  end

  def handle_event("save", %{"search" => params}, socket) do
    {:noreply, socket |> push_patch(to: Routes.live_path(socket, __MODULE__, params))}
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
