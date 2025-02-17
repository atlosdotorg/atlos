defmodule PlatformWeb.MediaLive.Index do
  alias Platform.Material.Media
  use PlatformWeb, :live_view
  alias Platform.Material
  alias Platform.Material.Attribute

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:title, "Incidents")
     |> stream(:media_stream, [], dom_id: &"incident-#{&1.slug}")}
  end

  defp handle_params_internal(params, socket) do
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

    membership_id = if is_nil(membership), do: nil, else: membership.id

    # Update the user's prefered incident display, if necessary
    Task.start(fn ->
      Platform.Accounts.update_user_preferences(socket.assigns.current_user, %{
        active_incidents_tab: display,
        active_project_membership_id: membership_id,
        active_incidents_tab_params: params,
        active_incidents_tab_params_time: NaiveDateTime.utc_now()
      })
    end)

    # Pull cursor information from params. We used to use cursor-based pagination
    # but people didn't like it, so we're using page-based pagination now. Miles hasn't
    # removed the cursor code, so you can still use it if you want to.
    page =
      Ecto.Changeset.get_field(
        changeset,
        :page,
        1
      )
      |> max(1)

    search_keywords = [
      limit: if(display == "map", do: 100_000, else: 51),
      offset: (page - 1) * 51,
      hydrate: display != "map"
    ]

    results =
      search_media(
        socket,
        changeset,
        # Ideally we would put these params in search_media, but since this is map-specific logic, it'll only be called here (it's not possible to "load more" on the map)
        search_keywords
      )

    socket
    |> assign(
      :changeset,
      changeset
    )
    |> assign(:display, display)
    |> assign(:full_width, display == "table")
    |> assign(:query_params, params)
    |> assign(:active_project, active_project)
    |> assign(:results, results)
    |> assign(:root_pid, self())
    |> assign(:page, page)
    |> assign(:editing, nil)
    |> assign_media(results.entries)
    |> assign(:bulk_background_task, nil)
    |> assign(
      :user_projects,
      Platform.Projects.list_projects_for_user(socket.assigns.current_user)
    )
    |> assign_attributes(active_project)
    |> then(fn s ->
      if display == "table",
        do:
          assign(
            s,
            :source_cols,
            Enum.min([
              Enum.max(results.entries |> Enum.map(&length(&1.versions)), &>=/2, fn -> 0 end) -
                1,
              20
            ])
          ),
        else: s
    end)
  end

  def assign_attributes(socket, project) do
    attributes = Attribute.active_attributes(project: project) |> Enum.filter(&is_nil(&1.parent))

    groups =
      case project do
        nil -> [:core]
        _ -> project.attribute_groups
      end

    attributes_with_groups =
      Enum.map(attributes, fn a ->
        member_of = Enum.find(groups, &(not is_atom(&1) and Enum.member?(&1.member_ids, a.name)))

        group =
          cond do
            not is_nil(member_of) -> member_of
            is_atom(a.name) -> :core
            true -> :unassigned
          end

        {a, group}
      end)

    # Sort by group ordering, then attribute ordering
    attributes_with_groups =
      Enum.sort_by(attributes_with_groups, fn {_, g} ->
        {if(is_atom(g), do: -1, else: g.ordering)}
      end)

    socket
    |> assign(
      :attributes,
      attributes
    )
    |> assign(
      :attributes_with_groups,
      attributes_with_groups
    )
  end

  def handle_params(params, _uri, socket) do
    {:noreply, handle_params_internal(params, socket)}
  end

  defp assign_media(socket, media) do
    existing_media = Map.get(socket.assigns, :media, [])

    socket
    |> assign(:media, media)
    |> then(fn s ->
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

  defp assign_update_media(socket, media_id) do
    existing_media = Map.get(socket.assigns, :media, [])
    new_media = Material.get_media(media_id, for_user: socket.assigns.current_user)

    socket
    |> assign(
      :media,
      existing_media |> Enum.map(fn m -> if(m.id == media_id, do: new_media, else: m) end)
    )
    |> stream_insert(:media_stream, new_media, dom_id: &"incident-#{&1.slug}")
  end

  defp search_media(socket, c, pagination_opts) do
    {query, pagination_options} =
      Material.MediaSearch.search_query(Material.Media, c, socket.assigns.current_user)

    query
    |> Material.MediaSearch.filter_viewable(socket.assigns.current_user)
    |> Material.query_media_paginated(
      Keyword.merge(Keyword.merge(pagination_options, pagination_opts),
        for_user: socket.assigns.current_user
      )
    )
  end

  defp apply_bulk_action(socket, selection, action, during_message, result_message) do
    main_process = self()

    socket
    |> assign(:bulk_background_task_name, during_message)
    |> assign_async(:bulk_background_task, fn ->
      # Action should return :ok or :error
      media =
        case Jason.decode(selection) do
          {:ok, %{"all" => true}} ->
            {query, _pagination_options} =
              Material.MediaSearch.search_query(
                Material.Media,
                socket.assigns.changeset,
                socket.assigns.current_user
              )

            Platform.Material.query_media(
              query
              |> Material.MediaSearch.filter_viewable(socket.assigns.current_user),
              for_user: socket.assigns.current_user
            )

          {:ok, x} when is_list(x) ->
            socket.assigns.media
            |> Enum.filter(&Enum.member?(x, to_string(&1.id)))

          _ ->
            []
        end

      if Enum.empty?(media) do
        raise PlatformWeb.Errors.BadRequest, "No media selected"
      end

      results =
        Enum.to_list(
          Task.async_stream(
            media,
            fn item ->
              try do
                action.(item)
              rescue
                _error ->
                  :error
              end
            end,
            max_concurrency: 10,
            timeout: 60 * 1000
          )
        )

      success_count = Enum.count(results, &(&1 == {:ok, :ok}))
      failure_count = Enum.count(results, &(&1 == {:ok, :error}))

      # Tell the main process to refresh the data
      send(main_process, {:refresh_data})

      {:ok,
       %{
         bulk_background_task: %{
           success_count: success_count,
           failure_count: failure_count,
           message: result_message
         }
       }}
    end)
  end

  def handle_event("bulk_apply_tag", %{"tag" => tag, "selection" => selection}, socket) do
    {:noreply,
     socket
     |> apply_bulk_action(
       selection,
       fn media ->
         if (media.attr_tags || []) |> Enum.member?(tag) do
           :ok
         else
           case Platform.Material.update_media_attribute_audited(
                  media,
                  Platform.Material.Attribute.get_attribute(:tags),
                  socket.assigns.current_user,
                  %{"attr_tags" => (media.attr_tags || []) ++ [tag]}
                ) do
             {:ok, _} -> :ok
             _ -> :error
           end
         end
       end,
       "Applying the tag #{tag}...",
       "Applied the tag #{tag}."
     )}
  end

  def handle_event("bulk_apply_status", %{"status" => status, "selection" => selection}, socket) do
    {:noreply,
     socket
     |> apply_bulk_action(
       selection,
       fn media ->
         if media.attr_status == status do
           :ok
         else
           case Platform.Material.update_media_attribute_audited(
                  media,
                  Platform.Material.Attribute.get_attribute(:status),
                  socket.assigns.current_user,
                  %{"attr_status" => status}
                ) do
             {:ok, _} -> :ok
             {:error, _} -> :error
           end
         end
       end,
       "Setting status to #{status}...",
       "Status set to #{status}."
     )}
  end

  def handle_event(
        "bulk_copy_to_project",
        %{"project-id" => project_id, "selection" => selection},
        socket
      ) do
    project = Platform.Projects.get_project!(project_id)

    if not Platform.Permissions.can_add_media_to_project?(socket.assigns.current_user, project) do
      raise PlatformWeb.Errors.Unauthorized,
            "You don't have permission to add media to this project."
    end

    {:noreply,
     socket
     |> apply_bulk_action(
       selection,
       fn media ->
         case Material.copy_media_to_project_audited(
                media,
                project,
                socket.assigns.current_user
              ) do
           {:ok, new_media} ->
             Platform.Auditor.log(
               :media_copied,
               %{
                 source: media.slug,
                 destination: project.id,
                 destination_media_slug: new_media.slug
               },
               socket
             )

             :ok

           {:error, %Ecto.Changeset{} = _cs} ->
             :error
         end
       end,
       "Copying to #{project.name |> Platform.Utils.truncate()}...",
       "Copied into #{project.name |> Platform.Utils.truncate()}."
     )}
  end

  def handle_event("validate", params, socket) do
    handle_event("save", params, socket)
  end

  def handle_event("save", %{"search" => params}, socket) do
    # Also reset the pagination index, since we're doing a new search
    merged_params =
      params
      |> Map.delete("page")

    {:noreply,
     socket
     |> push_patch(to: Routes.live_path(socket, __MODULE__, merged_params), replace: true)}
  end

  def handle_event(
        "edit_attribute",
        %{"attribute" => attr_name, "media-id" => media_id} = _params,
        socket
      ) do
    media = Enum.find(socket.assigns.media, &(&1.id == media_id))

    if not is_nil(media) and
         Platform.Permissions.can_edit_media?(
           socket.assigns.current_user,
           media,
           Attribute.get_attribute(attr_name, project: media.project)
         ) do
      {:noreply,
       socket
       |> assign(
         :editing,
         {media, attr_name}
       )}
    else
      {:noreply,
       socket
       |> put_flash(
         :error,
         "You cannot edit this data on #{Media.slug_to_display(media)}."
       )}
    end
  end

  def handle_event("dismiss_bulk_background_task", _params, socket) do
    {:noreply, socket |> assign(:bulk_background_task, nil)}
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
       |> assign_update_media(updated_media.id)
       |> put_flash(:info, "Your changes were applied successfully.")}
    end
  end

  def handle_info(
        {:refresh_data},
        socket
      ) do
    {:noreply, handle_params_internal(socket.assigns.query_params, socket)}
  end
end
