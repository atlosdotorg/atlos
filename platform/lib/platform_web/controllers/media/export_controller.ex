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

    field_list =
      (media
       |> Map.put(:latitude, lat)
       |> Map.put(:longitude, lon)
       |> Map.to_list()
       |> Enum.map(fn {k, v} ->
         name = k |> to_string()

         if String.starts_with?(name, "attr_") do
           {String.slice(name, 5..String.length(name)) |> String.to_atom(), v}
         else
           {k, v}
         end
       end)) ++
        (media.versions
         |> Enum.filter(&(&1.visibility == :visible))
         |> Enum.with_index(1)
         |> Enum.map(fn {item, idx} -> {"source_" <> to_string(idx), item.source_url} end))

    field_list
    |> Enum.filter(fn {k, _v} -> Enum.member?(fields, k) end)
    |> Map.new(fn {k, v} ->
      {k,
       case v do
         [_ | _] -> Enum.join(v, ", ")
         _ -> v
       end}
    end)
  end

  def create(conn, params) do
    c = MediaSearch.changeset(params)
    {full_query, _} = MediaSearch.search_query(c)
    final_query = MediaSearch.filter_viewable(full_query, conn.assigns.current_user)
    results = Material.query_media(final_query)

    max_num_versions =
      Enum.max(
        results
        |> Enum.map(fn media ->
          length(media.versions |> Enum.filter(&(&1.visibility == :visible)))
        end)
      )

    Temp.track!()
    path = Temp.path!(suffix: "atlos-export.csv")
    file = File.open!(path, [:write, :utf8])

    fields =
      [:slug, :inserted_at, :updated_at, :latitude, :longitude] ++
        Attribute.attribute_names(false) ++
        Enum.map(1..max_num_versions, &("source_" <> to_string(&1)))

    results
    |> Enum.map(&format_media(&1, fields))
    |> CSV.encode(headers: fields)
    |> Enum.each(&IO.write(file, &1))

    :ok = File.close(file)

    Platform.Auditor.log(:bulk_export, params, conn)

    send_download(conn, {:file, path})
  end
end
