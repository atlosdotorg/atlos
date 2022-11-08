defmodule Platform.Workers.AutoMetadata do
  alias Platform.Material

  require Logger

  use Oban.Worker,
    queue: :auto_metadata,
    priority: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_id" => id} = _args}) do
    media = Material.get_media!(id)

    Logger.info("Updating metadata for #{media.slug}.")

    Material.update_media_auto_metadata(media, %{
      _updated: DateTime.utc_now() |> DateTime.to_iso8601()
    })

    :ok
  end
end
