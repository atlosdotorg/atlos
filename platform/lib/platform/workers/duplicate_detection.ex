defmodule Platform.Workers.DuplicateDetector do
  alias Platform.Material

  require Logger

  use Oban.Worker,
    queue: :duplicate_detection,
    priority: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_version_id" => id} = _args}) do
    version = Material.get_media_version!(id)
    media = Material.get_media!(version.media_id) |> Platform.Repo.preload([:project, :versions])

    Logger.info("Checking for duplicate artifacts: #{media.slug}")

    :ok
  end
end
