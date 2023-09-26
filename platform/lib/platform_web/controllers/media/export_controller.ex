defmodule PlatformWeb.ExportController do
  use PlatformWeb, :controller

  alias Platform.Material
  alias Material.Attribute
  alias Material.MediaSearch

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
          [_ | _] -> Enum.join(v, ", ")
          _ -> v
        end}
     end), custom_attribute_names |> Enum.map(&format_field_name/1)}
  end

  defp format_field_name(name) do
    name
    |> to_string()
    |> String.replace("_", " ")
    # Put into title case
    |> String.split(" ")
    |> Enum.map(fn word ->
      String.capitalize(word)
    end)
    |> Enum.join(" ")
  end

  def create(conn, params) do
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
end
