defmodule Platform.Workers.AutoMetadata do
  alias Platform.Material

  require Logger

  use Oban.Worker,
    queue: :auto_metadata,
    priority: 3

  defp reverse_geocode(lat, lon, opts \\ []) do
    with {:ok, status, _headers, body} when status in 200..299 <-
           :hackney.get(
             "https://nominatim.openstreetmap.org/reverse?#{URI.encode_query(lat: lat, lon: lon, format: "json")}",
             [
               {"Accept-Language", Keyword.get(opts, :language)}
             ],
             [],
             [:with_body]
           ),
         {:ok, data} <- Jason.decode(body),
         %{
           "licence" => license,
           "osm_id" => osm_id,
           "address" => address,
           "display_name" => display_name
         } <- data do
      %{
        attribution: license,
        osm_id: osm_id,
        address: address,
        formatted_address: display_name
      }
    else
      _ -> nil
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_id" => id} = _args}) do
    media = Material.get_media!(id)

    Logger.info("Updating metadata for #{media.slug}.")

    geocoding =
      try do
        with %Geo.Point{coordinates: {lon, lat}} <- media.attr_geolocation do
          %{
            english: reverse_geocode(lat, lon, language: "en"),
            base: reverse_geocode(lat, lon)
          }
        else
          _ ->
            nil
        end
      rescue
        err ->
          Logger.error("Encountered error while geocoding: #{err}")
          nil
      end

    Logger.info("Updated metadata for #{media.slug}!")

    Material.update_media_auto_metadata(media, %{
      time_generated: DateTime.utc_now() |> DateTime.to_iso8601(),
      geocoding: geocoding
    })

    :ok
  end
end
