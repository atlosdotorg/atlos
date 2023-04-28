defmodule Platform.DataMigrations.MediaVersionsMigrator do
  alias Platform.Uploads
  alias Platform.Material
  alias Platform.Material.MediaVersion
  alias Platform.Updates
  alias Platform.Accounts

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

    # HTTPS URL to the file
    old_file_location_url = Material.media_version_location(version, version.media)
    local_path = Path.join(temp_dir, version.file_location)

    # Download the file from the URL
    download_file(old_file_location_url, local_path)

    # Get the file size
    %{size: size} = File.stat!(local_path)

    artifact_data = %{
      "id" => Ecto.UUID.generate(),
      "file_location" => nil,
      "file_hash_sha256" => Platform.Utils.hash_sha256(local_path),
      "file_size" => size,
      "mime_type" => MIME.from_path(local_path),
      "type" => "upload"
    }

    Uploads.Logger.info("Good to go!")
  end
end
