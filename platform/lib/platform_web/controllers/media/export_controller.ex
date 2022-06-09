defmodule PlatformWeb.ExportController do
  use PlatformWeb, :controller

  alias Platform.Material
  alias Material.Attribute
  alias Material.MediaSearch

  def create(conn, params) do
    c = MediaSearch.changeset(params)
    {full_query, _} = MediaSearch.search_query(c)
    final_query = MediaSearch.filter_viewable(full_query, conn.assigns.current_user)
    results = Material.query_media(final_query)

    Temp.track!()
    path = Temp.path!(suffix: "atlos-export.csv")
    file = File.open!(path, [:write, :utf8])

    results
    |> CSV.encode(
      headers:
        [:slug, :inserted_at, :updated_at] ++
          Attribute.attribute_schema_fields()
    )
    |> Enum.each(&IO.write(file, &1))

    :ok = File.close(file)

    Platform.Auditor.log(:bulk_export, params, conn)

    send_download(conn, {:file, path})
  end
end
