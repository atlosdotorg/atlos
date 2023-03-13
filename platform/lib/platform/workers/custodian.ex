defmodule Platform.Workers.Custodian do
  alias Platform.Material

  require Logger

  use Oban.Worker,
    queue: :custodian,
    priority: 3

  defp refresh_stale_media_versions() do
    # Re-schedule media versions that are more than 24 hours old and still pending.

    Logger.info("Cleaning up pending media versions.")
    pending_media_versions = Material.get_pending_media_versions()

    for version <- pending_media_versions do
      if NaiveDateTime.diff(NaiveDateTime.local_now(), version.updated_at, :hour) > 24 do
        Logger.info("Re-scheduling media version #{version.id} for archival.")
        Material.archive_media_version(version)
      else
        Logger.info(
          "Media version #{version.id} is still pending, but not yet old enough to re-schedule."
        )
      end
    end
  end

  @impl Oban.Worker
  def perform(_) do
    refresh_stale_media_versions()

    # Add additional cleanup tasks here...

    :ok
  end
end
