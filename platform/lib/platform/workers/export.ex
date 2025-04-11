defmodule Platform.Workers.ExportWorker do
  use Oban.Worker,
  queue: :export,
  priority: 3

  alias Platform.Material
  alias Material.Attribute
  alias Material.MediaSearch
  alias Material.Media
  alias PlatformWeb.HTTPDownload
  alias Platform.Permissions
  alias Platform.Projects
  alias Platform.Utils
  alias Platform.Uploads.ExportFile
  alias Platform.Mailer
  alias Platform.Notifications
  alias Platform.Accounts

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "params" => params}}) do
    user = Platform.Accounts.get_user(user_id)

    try do
      signed_url = generate_csv_export_file(user, params)
      Notifications.send_message_notification_to_user(user, "Your export is ready: #{signed_url}")
      Mailer.construct_and_send(user.email, "Your Atlos export is ready", "#{signed_url}")
      :ok

    rescue
      exception ->
        Notifications.send_message_notification_to_user(user, "Your export failed. Please try again.")
        {:error, exception}
    end
  end

    defp format_media(%Material.Media{} = media, fields, user) do
      {lon, lat} =
        if is_nil(media.attr_geolocation) do
        {nil, nil}
      else
        media.attr_geolocation.coordinates
      end

    custom_attributes =
      Attribute.attributes(project: media.project)
      |> Enum.filter(&(&1.schema_field == :project_attributes))
      |> Enum.filter(&Permissions.can_view_attribute?(user, media, &1))

    field_list =
      (media
       |> Map.put(:latitude, lat)
       |> Map.put(:longitude, lon)
       |> Map.put(:project, media.project.name)
       |> Map.to_list()
       |> Enum.filter(fn {k, _v} ->
         attr = Attribute.get_attribute_by_schema_field(k, project: media.project)

         (not is_nil(attr) and Permissions.can_view_attribute?(user, media, attr)) or
           Enum.member?([:slug, :inserted_at, :updated_at, :latitude, :longitude], k)
       end)
       |> Enum.map(fn {k, v} ->
         name = k |> to_string()

         if String.starts_with?(name, "attr_") do
           {String.slice(name, 5..String.length(name)) |> String.to_existing_atom(), v}
         else
           {k, v}
         end
       end)) ++
        (custom_attributes
         |> Enum.map(fn attr ->
           {Platform.Material.Attribute.standardized_label(attr, project: media.project),
            Material.get_attribute_value(media, attr, format_dates: true)}
         end)) ++
        (media.versions
         |> Enum.filter(&(&1.visibility == :visible))
         |> Enum.with_index(1)
         |> Enum.map(fn {item, idx} -> {"source_" <> to_string(idx), item.source_url} end))

    custom_attribute_names =
      custom_attributes
      |> Enum.map(fn x ->
        Platform.Material.Attribute.standardized_label(x, project: media.project)
      end)

    allowed_field_names = Enum.map(fields ++ custom_attribute_names, &to_string/1)

    {field_list
     |> Enum.filter(fn {k, _v} ->
       Enum.member?(allowed_field_names, to_string(k))
     end)
     |> Map.new(fn {k, v} ->
       {format_field_name(k),
        case v do
          # Match lists of structs that contain a user field and format them
          # into comma-separated usernames (this is used, e.g., for assignees)
          [%{user: %Platform.Accounts.User{}} | _] ->
            v |> Enum.map(fn %{user: user} -> user.username end) |> Enum.join(", ")

          [_ | _] ->
            Enum.join(v, ", ")

          _ ->
            v
        end}
     end), custom_attribute_names |> Enum.map(&format_field_name/1)}
  end

  defp stream_to_file(file, query, fields, current_user, max_versions, page, page_size, custom_fields) do
  media_chunk =
    Material.query_media_paginated(query,
      for_user: current_user,
      limit: page_size,
      offset: (page - 1) * page_size
    ).entries
    |> Enum.map(fn media ->
      {row_data, _} = format_media(media, fields, current_user)

      row_with_all_fields =
        Enum.reduce(fields, %{}, fn field, acc ->
          case Map.fetch(row_data, format_field_name(field)) do
            {:ok, value} -> Map.put(acc, format_field_name(field), value)
            :error -> Map.put(acc, format_field_name(field), "")
          end
        end)

      fields
      |> Enum.map(&Map.get(row_with_all_fields, format_field_name(&1), ""))
    end)

  if Enum.empty?(media_chunk) do
    :ok
  else
    media_chunk
    |> CSV.encode(escape_formulas: true)
    |> Enum.each(&IO.write(file, &1))

    # Recurse to next page
    stream_to_file(file, query, fields, current_user, max_versions, page + 1, page_size, custom_fields)
  end
end

  defp get_max_versions_and_custom_attributes(query, current_user, fields_excluding_custom) do
    page_size = 50

    # Create a function that processes pages and accumulates both max versions and custom attributes
    process_pages = fn fetch_data, process_pages_fn, page_number, {current_max, current_names} ->
      {version_counts, custom_attribute_names} = fetch_data.(page_number)

      if Enum.empty?(version_counts) do
        # No more media to process
        {current_max, current_names}
      else
        # Update max count and custom attributes, then continue to next page
        new_max = Enum.max([current_max | version_counts])
        new_names = Enum.uniq(current_names ++ custom_attribute_names)
        process_pages_fn.(fetch_data, process_pages_fn, page_number + 1, {new_max, new_names})
      end
    end

    # Get both version counts and custom attribute names in a single pass
    fetch_data = fn page_number ->
      paginated_results = Material.query_media_paginated(query,
        for_user: current_user,
        limit: page_size,
        offset: (page_number - 1) * page_size
      ).entries

      # Get version counts
      version_counts = paginated_results
      |> Enum.map(fn media ->
        length(media.versions |> Enum.filter(&(&1.visibility == :visible)))
      end)

      # Get custom attribute names
      formatted = Enum.map(paginated_results, &format_media(&1, fields_excluding_custom, current_user))
      custom_attribute_names = formatted
      |> Enum.map(fn {_, fields} -> fields end)
      |> List.flatten()
      |> Enum.uniq()

      {version_counts, custom_attribute_names}
    end

    # Process all pages, starting with initial values
    {max_count, unique_custom_attributes} = process_pages.(fetch_data, process_pages, 1, {0, []})

    {max_count, unique_custom_attributes}
  end
  defp format_field_name(name) do
    name
    |> to_string()
  end

  defp generate_csv_export_file(user, params) do
    c = MediaSearch.changeset(params)
    {full_query, _} = MediaSearch.search_query(c)
    IO.inspect(full_query)
    final_query = MediaSearch.filter_viewable(full_query, user)

    # Prepare field headers
    fields_excluding_custom = [:slug, :inserted_at, :updated_at, :latitude, :longitude] ++ Attribute.attribute_names()
    {max_num_versions, custom_attribute_names} = get_max_versions_and_custom_attributes(final_query, user, fields_excluding_custom)

    fields_excluding_custom =
      fields_excluding_custom ++
        (if max_num_versions > 0 do
          Enum.map(1..max_num_versions, &("source_" <> to_string(&1)))
        else
          []
        end)
      |> Enum.reject(&(&1 in [:geolocation]))

    all_headers = (fields_excluding_custom ++ custom_attribute_names) |> Enum.map(&format_field_name/1)
    IO.inspect("We got hereeeeeeeeee")
    # Track and open temp file
    Temp.track!()
    path = Temp.path!(suffix: "atlos-export.csv")
    {:ok, file} = File.open(path, [:write, :utf8])

    # Write CSV headers
    header_row = CSV.encode([all_headers], escape_formulas: true) |> Enum.join("")
    IO.write(file, header_row)

    # Paginate and write rows
    chunk_size = 50
    stream_to_file(file, final_query, all_headers, user, max_num_versions, 1, chunk_size, custom_attribute_names)

    File.close(file)

    Platform.Auditor.log(:bulk_export, params)

    # Upload file to S3
    scope = %{
      user_id: user.id,
      export_type: "csv",
      prefix: "atlos-export",
      content_type: "text/csv",
      suffix: :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    }

    {:ok, filename} = ExportFile.store({path, scope})
    url = ExportFile.url({filename, scope}, signed: true, expires_in: 24 * 60 * 60)

    File.rm(path)
    url
  end
end
