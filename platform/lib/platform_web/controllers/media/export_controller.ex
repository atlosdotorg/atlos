defmodule PlatformWeb.ExportController do
  require Logger
  use PlatformWeb, :controller

  alias Platform.Material
  alias Material.Attribute
  alias Material.MediaSearch
  alias Material.Media
  alias PlatformWeb.HTTPDownload
  alias Platform.Permissions
  alias Platform.Projects
  alias Platform.Utils

  defp format_media(%Material.Media{} = media, fields) do
    {lon, lat} =
      if is_nil(media.attr_geolocation) do
        {nil, nil}
      else
        media.attr_geolocation.coordinates
      end

    custom_attributes =
      Attribute.attributes(project: media.project)
      |> Enum.filter(&(&1.schema_field == :project_attributes))

    name_for_custom_attribute = fn attr ->
      "#{attr.label}"
    end

    field_list =
      (media
       |> Map.put(:latitude, lat)
       |> Map.put(:longitude, lon)
       |> Map.put(:project, media.project.name)
       |> Map.to_list()
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
           {name_for_custom_attribute.(attr),
            Material.get_attribute_value(media, attr, format_dates: true)}
         end)) ++
        (media.versions
         |> Enum.filter(&(&1.visibility == :visible))
         |> Enum.with_index(1)
         |> Enum.map(fn {item, idx} -> {"source_" <> to_string(idx), item.source_url} end))

    custom_attribute_names = custom_attributes |> Enum.map(name_for_custom_attribute)

    {field_list
     |> Enum.filter(fn {k, _v} ->
       Enum.member?(fields ++ custom_attribute_names, k)
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

  defp format_field_name(name) do
    name
    |> to_string()
  end

  def create_csv_export(conn, params) do
    c = MediaSearch.changeset(params)
    {full_query, _} = MediaSearch.search_query(c)
    final_query = MediaSearch.filter_viewable(full_query, conn.assigns.current_user)
    results = Material.query_media(final_query, for_user: conn.assigns.current_user)

    max_num_versions =
      Enum.max(
        results
        |> Enum.map(fn media ->
          length(media.versions |> Enum.filter(&(&1.visibility == :visible)))
        end),
        fn -> 0 end
      )

    Temp.track!()
    path = Temp.path!(suffix: "atlos-export.csv")
    file = File.open!(path, [:write, :utf8])

    fields_excluding_custom =
      [:slug, :project, :inserted_at, :updated_at, :latitude, :longitude] ++
        Attribute.attribute_names() ++
        Enum.map(1..max_num_versions, &("source_" <> to_string(&1)))

    # Remove "weird" fields that are redundant or not useful
    fields_excluding_custom =
      Enum.reject(fields_excluding_custom, fn field ->
        field in [:geolocation]
      end)

    formatted = Enum.map(results, &format_media(&1, fields_excluding_custom))
    media = formatted |> Enum.map(fn {media, _} -> media end)

    custom_attribute_names =
      formatted |> Enum.map(fn {_, fields} -> fields end) |> List.flatten() |> Enum.uniq()

    media
    |> CSV.encode(
      headers:
        (fields_excluding_custom ++ custom_attribute_names) |> Enum.map(&format_field_name/1),
      escape_formulas: true
    )
    |> Enum.each(&IO.write(file, &1))

    :ok = File.close(file)

    Platform.Auditor.log(:bulk_export, params, conn)

    # The filename should be atlos-export-YYYY-MM-DD.csv
    user_visible_filename = "atlos-export-#{Date.utc_today()}.csv"
    send_download(conn, {:file, path}, filename: user_visible_filename)
  end

  def create_project_full_export(conn, %{"project_id" => project_id}) do
    project = Projects.get_project!(project_id)

    if Permissions.can_export_full?(conn.assigns.current_user, project) do
      create_full_export(conn, %{"project_id" => project.id})
    else
      raise PlatformWeb.Errors.Unauthorized,
            "Only project managers and owners can export full data"
    end
  end

  defp create_full_export(conn, params) do
    c = MediaSearch.changeset(params)
    root_folder_name = "atlos-export-#{Date.utc_today()}"

    project_id = Map.get(params, "project_id")
    project = Projects.get_project!(project_id)

    {full_query, _} = MediaSearch.search_query(c)
    final_query = MediaSearch.filter_viewable(full_query, conn.assigns.current_user)

    results =
      Stream.concat([
        Material.query_media(final_query, for_user: conn.assigns.current_user)
        |> Stream.flat_map(fn media ->
          media_slug = Media.slug_to_display(media)
          Logger.debug("Checking media #{media_slug}")

          media.versions
          |> Stream.filter(&Permissions.can_view_media_version?(conn.assigns.current_user, &1))
          |> Stream.flat_map(fn version ->
            Logger.debug("Checking version #{media_slug}/#{version.scoped_id}")
            folder_name = "#{root_folder_name}/#{media_slug}/#{media_slug}-#{version.scoped_id}"

            version.artifacts
            |> Stream.map(fn artifact ->
              location = Material.media_version_artifact_location(artifact)
              f_extension = artifact.file_location |> String.split(".") |> List.last("data")
              fname = "#{artifact.type}_#{media_slug}-#{version.scoped_id}.#{f_extension}"
              Logger.debug("Artifact #{fname}: #{location}")
              Zstream.entry("#{folder_name}/#{fname}", HTTPDownload.stream!(location))
            end)
            |> Stream.concat([
              Zstream.entry("#{folder_name}/metadata.json", [Jason.encode!(version)])
            ])
          end)
          |> Stream.concat([
            Zstream.entry("#{root_folder_name}/#{media_slug}/metadata.json", [
              Jason.encode!(media)
            ]),
            Zstream.entry("#{root_folder_name}/#{media_slug}/updates.json", [
              media.updates
              |> Permissions.filter_to_viewable_updates(conn.assigns.current_user)
              |> Jason.encode!()
            ])
          ])
        end),
        [Zstream.entry("#{root_folder_name}/project.json", [Jason.encode!(project)])]
      ])
      |> Zstream.zip()

    Logger.debug("Sending file: #{inspect(results)}")

    conn =
      conn
      |> put_resp_content_type("application/zip")
      |> put_resp_header(
        "content-disposition",
        "attachment; filename=\"#{root_folder_name}.zip\""
      )
      |> send_chunked(:ok)

    # Not sure what chunk size to choose
    results
    |> Stream.chunk_every(256)
    |> Stream.map(fn chn ->
      Logger.debug("Sending chunk of size #{Enum.count(chn)}")
      conn |> chunk(chn)
    end)
    |> Stream.run()

    conn
  end

  def create_backup_codes_export(conn, _params) do
    user = conn.assigns.current_user

    codes =
      user.recovery_codes
      |> Enum.map(&Utils.format_recovery_code(&1))

    path = Temp.path!(suffix: "atlos-backup-codes.txt")
    file = File.open!(path, [:write, :utf8])

    file
    |> IO.write("""
    Atlos Backup Codes

    #{1..length(codes) |> Enum.zip(codes) |> Enum.map(fn {idx, code} -> "#{idx}. #{code}" end) |> Enum.join("\n")}

    (#{user.email})

    - You can only use each code once.
    - Generate more at Account > Manage Account > Multi-factor auth
    - Generated at #{DateTime.utc_now()}
    """)

    :ok = File.close(file)
    send_download(conn, {:file, path}, filename: "atlos-backup-codes.txt")
  end
end
