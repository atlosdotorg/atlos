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

    media
    |> Map.put(:attr_latitude, lat)
    |> Map.put(:attr_longitude, lon)
    |> Map.to_list()
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

    Temp.track!()
    path = Temp.path!(suffix: "atlos-export.csv")
    file = File.open!(path, [:write, :utf8])

    fields =
      [:slug, :inserted_at, :updated_at, :attr_latitude, :attr_longitude] ++
        Attribute.attribute_schema_fields()

    results
    |> Enum.map(&format_media(&1, fields))
    |> CSV.encode(headers: fields)
    |> Enum.each(&IO.write(file, &1))

    :ok = File.close(file)

    Platform.Auditor.log(:bulk_export, params, conn)

    send_download(conn, {:file, path})
  end
end
