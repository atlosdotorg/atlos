defmodule PlatformWeb.MediaLive.Index do
  use PlatformWeb, :live_view
  alias Platform.Material
  alias Platform.Material.Attribute

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Incidents")
     |> stream(:media_stream, [], dom_id: &"incident-#{&1.slug}")}
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

    active_project = Platform.Projects.get_project(params["project_id"])

    membership =
      Platform.Projects.get_project_membership_by_user_and_project(
        socket.assigns.current_user,
        active_project
      )

    membership_id = if not is_nil(membership), do: membership.id, else: nil

    # Update the user's prefered incident display, if necessary
    Platform.Accounts.update_user_preferences(socket.assigns.current_user, %{
      active_incidents_tab: display,
      active_project_membership_id: membership_id,
      active_incidents_tab_params: params,
      active_incidents_tab_params_time: NaiveDateTime.utc_now()
    })

    # Pull cursor information from params
    before_cursor = params["bc"]
    after_cursor = params["ac"]
    pagination_index = (params["pi"] || "0") |> String.to_integer()

    search_keywords = [
      limit: if(display == "map", do: 100_000, else: 51),
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
     |> assign(:root_pid, self())
     |> assign(:pagination_index, pagination_index)
     |> assign(:editing, nil)
     |> assign_media(results.entries)
     |> assign(:selected_ids, [])
     |> assign(
       :user_projects,
       Platform.Projects.list_projects_for_user(socket.assigns.current_user)
     )
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
             Enum.min([
               Enum.max(results.entries |> Enum.map(&length(&1.versions)), &>=/2, fn -> 0 end),
               2
             ])
           ),
         else: s
     end)}
  end

  defp assign_media(socket, media) do
    IO.puts("Assigning media: length is #{Enum.count(media)}")

    existing_media = Map.get(socket.assigns, :media, [])

    socket
    |> assign(:media, media)
    |> then(fn s ->
      IO.puts("Existing media: length is #{Enum.count(existing_media)}")

      s =
        Enum.reduce(existing_media, s, fn m, s ->
          stream_delete_by_dom_id(s, :media_stream, "incident-#{m.slug}")
        end)

      s =
        Enum.reduce(media, s, fn m, s ->
          stream_insert(s, :media_stream, m, dom_id: "incident-#{m.slug}")
        end)

      s
    end)
  end

  defp assign_update_media(socket, media) do
    existing_media = Map.get(socket.assigns, :media, [])

    socket
    |> assign(
      :media,
      existing_media |> Enum.map(fn m -> if(m.id == media.id, do: media, else: m) end)
    )
    |> stream_insert(:media_stream, media, dom_id: &"incident-#{&1.slug}")
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

  defp apply_bulk_action(socket, action) do
    media =
      socket.assigns.media
      |> Enum.filter(&Enum.member?(socket.assigns.selected_ids, &1.id))
      |> Enum.map(action)

    Enum.reduce(media, socket, fn media, socket ->
      assign_update_media(socket, media)
    end)
  end

  def handle_event("select", %{"slug" => slug}, socket) do
    media = Enum.find(socket.assigns.media, &(&1.slug == slug))
    prev_was_selected = Enum.member?(socket.assigns.selected_ids, media.id)

    {:noreply,
     socket
     |> assign(
       :selected_ids,
       if(prev_was_selected,
         do: Enum.filter(socket.assigns.selected_ids, &(&1 != media.id)),
         else: [media.id | socket.assigns.selected_ids]
       )
     )
     |> assign_update_media(media)}
  end

  def handle_event("select_all", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_ids, socket.assigns.media |> Enum.map(& &1.id))
     |> assign_media(socket.assigns.media)}
  end

  def handle_event("deselect_all", _params, socket) do
    {:noreply, socket |> assign(:selected_ids, []) |> assign_media(socket.assigns.media)}
  end

  def handle_event("apply_tag", %{"tag" => tag}, socket) do
    {:noreply,
     socket
     |> put_flash(
       :info,
       "Applied the tag \"#{tag}\" to #{length(socket.assigns.selected_ids)} incident(s)"
     )
     |> apply_bulk_action(fn media ->
       if (media.attr_tags || []) |> Enum.member?(tag) do
         media
       else
         {:ok, media} =
           Platform.Material.update_media_attribute_audited(
             media,
             Platform.Material.Attribute.get_attribute(:tags),
             socket.assigns.current_user,
             %{"attr_tags" => (media.attr_tags || []) ++ [tag]}
           )

         media
       end
     end)}
  end

  def handle_event("apply_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> put_flash(
       :info,
       "Status set to \"#{status}\" on the #{length(socket.assigns.selected_ids)} selected incident(s)"
     )
     |> apply_bulk_action(fn media ->
       if media.attr_status == status do
         media
       else
         {:ok, media} =
           Platform.Material.update_media_attribute_audited(
             media,
             Platform.Material.Attribute.get_attribute(:status),
             socket.assigns.current_user,
             %{"attr_status" => status}
           )

         media
       end
     end)}
  end

  def handle_event("validate", params, socket) do
    handle_event("save", params, socket)
  end

  def handle_event("save", %{"search" => params}, socket) do
    # Also reset the pagination index, since we're doing a new search
    merged_params =
      params
      |> Map.delete("bc")
      |> Map.delete("ac")
      |> Map.delete("pi")

    {:noreply,
     socket
     |> push_patch(to: Routes.live_path(socket, __MODULE__, merged_params), replace: true)}
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
       |> assign_update_media(updated_media)
       |> put_flash(:info, "Your changes were applied successfully.")}
    end
  end
end
