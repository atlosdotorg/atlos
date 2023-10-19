defmodule Platform.DataMigrations.MediaVersionsMigrator do
  alias Platform.Material
  alias Platform.Material.MediaVersion

  import Ecto.Query

  require Logger

  defp download_file(from_url, into_file) do
    {_, 0} =
      System.cmd(
        "curl",
        [
          "-L",
          from_url,
          "-o",
          into_file
        ],
        into: IO.stream()
      )
  end

  def migrate_media_version(%MediaVersion{} = version) do
    Temp.track!()
    temp_dir = Temp.mkdir!()
    id = Ecto.UUID.generate()

    # HTTPS URL to the file
    old_file_location_url = Material.media_version_location(version, version.media)
    local_path = Path.join(temp_dir, version.file_location)

    # Download the file from the URL
    download_file(old_file_location_url, local_path)

    # Get the file size
    %{size: size} = File.stat!(local_path)

    # Store the file as an artifact
    {:ok, remote_path} = Platform.Uploads.MediaVersionArtifact.store({local_path, %{id: id}})

    artifact_data = %{
      "id" => id,
      "file_location" => remote_path,
      "file_hash_sha256" => Platform.Utils.hash_sha256(local_path),
      "file_size" => size,
      "mime_type" => MIME.from_path(local_path),
      "type" => "upload"
    }

    # Update the media version
    Platform.Material.update_media_version(version, %{
      artifacts: [artifact_data]
    })

    # Schedule for rearchival
    Material.rearchive_media_version(version)

    # Cleanup
    Temp.cleanup()
  end

  def get_media_versions_to_migrate() do
    # Get all media versions that are not user provided
    query =
      from(mv in MediaVersion,
        where: not is_nil(mv.file_location) and is_nil(mv.artifacts),
        preload: [:media]
      )

    Platform.Repo.all(query)
    |> Enum.filter(&(not String.starts_with?(&1.file_location, "https://")))
  end

  def migrate_all_media_versions() do
    Logger.info("Migrating media versions...")

    to_migrate = get_media_versions_to_migrate()

    Logger.info("Migrating #{length(to_migrate)} media versions...")

    Enum.zip(to_migrate, 1..length(to_migrate))
    |> Enum.each(fn {version, index} ->
      Logger.info(
        "Migrating media version #{index} of #{length(to_migrate)}; available at /incidents/#{version.media.slug}/detail/#{version.scoped_id}"
      )

      try do
        migrate_media_version(version)
      rescue
        e ->
          Logger.error("Failed to migrate media version #{version.id}: #{inspect(e)}")
      end
    end)

    Logger.info("Done migrating media versions.")
  end
end
