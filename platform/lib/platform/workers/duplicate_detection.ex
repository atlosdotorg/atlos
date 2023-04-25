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

    # First, we find all the perceptual hashes for the media version.
    hashes =
      Enum.map(version.artifacts, fn artifact ->
        artifact.perceptual_hashes |> Map.get("computed", [])
      end)
      |> List.flatten()

    # Next, we search for media versions that have perceptual hashes that are similar to these
    # perceptual hashes.
  end
end
