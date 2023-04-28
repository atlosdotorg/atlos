defmodule Platform.Workers.Archiver do
  alias Platform.Material
  alias Platform.Material.MediaVersion
  alias Platform.Auditor
  alias Platform.Uploads

  require Logger

  use Oban.Worker,
    queue: :media_archival,
    priority: 3

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

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_version_id" => id} = args}) do
    is_rearchive_request = Map.get(args, "rearchive", false)

    Logger.info("Archiving media version #{id}...")
    version = Material.get_media_version!(id)

    %MediaVersion{status: status, media_id: media_id} = version

    if not (status != :pending and not is_rearchive_request) do
      Logger.info("Archiving media version #{id}... (got media #{media_id})")

      hide_version_on_failure = Map.get(args, "hide_version_on_failure", false)

      # Cleanup any existing tempfiles. (The worker is a long-running task.)
      # In case we haven't already
      Temp.track!()
      Temp.cleanup()

      result =
        try do
          # Submit to the Internet Archive for archival
          Material.submit_for_external_archival(version)

          # Archive the page, and download the media from it
          temp_dir = Temp.mkdir!()
          utils_dir = System.get_env("UTILS_DIR", "utils")

          # Download the media data
          case version.upload_type do
            :direct ->
              {_, 0} =
                System.cmd(
                  "env",
                  [
                    "-i",
                    "HOME=#{System.get_env("HOME")}",
                    "PATH=#{System.get_env("PATH")}",
                    "USER=#{System.get_env("USER")}",
                    "LANG=#{System.get_env("LANG")}",
                    "LC_CTYPE=#{System.get_env("LANG")}",
                    "poetry",
                    "run",
                    "./archive.py",
                    "--out",
                    temp_dir,
                    "--auto-archiver-config",
                    "auto_archiver_config.yaml",
                    "--url",
                    version.source_url
                  ],
                  cd: utils_dir
                )

              metadata_file = Path.join(temp_dir, "metadata.json")
              metadata = File.read!(metadata_file) |> Jason.decode!()

              # Upload the artifacts
              artifacts =
                Enum.map(metadata["artifacts"], fn artifact ->
                  id = Ecto.UUID.generate()
                  loc = Path.join(temp_dir, artifact["file"])

                  {:ok, remote_path} = Uploads.MediaVersionArtifact.store({loc, %{id: id}})

                  %{size: size} = File.stat!(loc)

                  # If the file is bigger than 5GB, we don't want to store it
                  if size > 5 * 1024 * 1024 * 1024 do
                    :skip
                  else
                    %{
                      id: id,
                      file_location: remote_path,
                      file_hash_sha256: artifact["sha256"],
                      file_size: size,
                      mime_type: MIME.from_path(artifact["file"]),
                      perceptual_hashes: %{
                        "computed" => Map.get(artifact, "perceptual_hashes", [])
                      },
                      type: String.to_existing_atom(artifact["kind"])
                    }
                  end
                end)
                |> Enum.filter(&(&1 != :skip))

              # Update the media version
              version_map = %{
                status: :complete,
                # Append the artifacts; some may already exist
                artifacts: (version.artifacts || []) ++ artifacts,
                metadata: %{
                  auto_archive_successful: Map.get(metadata, "auto_archive_successful", false),
                  crawl_successful: Map.get(metadata, "crawl_successful", false),
                  page_info: Map.get(metadata, "page_info"),
                  content_info: Map.get(metadata, "content_info"),
                  is_likely_authwalled: Map.get(metadata, "is_likely_authwalled", false)
                }
              }

              {:ok, version} = Material.update_media_version(version, version_map)

              version

            :user_provided ->
              new_artifacts =
                Enum.map(version.artifacts, fn artifact ->
                  file_out_loc = Path.join(temp_dir, artifact.file_location)

                  # Download the media
                  download_file(
                    Material.media_version_artifact_location(artifact),
                    file_out_loc
                  )

                  {_, 0} =
                    System.cmd(
                      "env",
                      [
                        "-i",
                        "HOME=#{System.get_env("HOME")}",
                        "PATH=#{System.get_env("PATH")}",
                        "USER=#{System.get_env("USER")}",
                        "LANG=#{System.get_env("LANG")}",
                        "LC_CTYPE=#{System.get_env("LANG")}",
                        "poetry",
                        "run",
                        "./archive.py",
                        "--out",
                        temp_dir,
                        "--auto-archiver-config",
                        "auto_archiver_config.yaml",
                        "--file",
                        file_out_loc
                      ],
                      cd: utils_dir
                    )

                  %{size: size} = File.stat!(file_out_loc)

                  metadata_file = Path.join(temp_dir, "metadata.json")
                  metadata = File.read!(metadata_file) |> Jason.decode!()

                  data =
                    Map.get(metadata, "artifacts", [])
                    |> Enum.find(&(&1["sha256"] == artifact.file_hash_sha256))

                  %{
                    id: artifact.id,
                    file_location: artifact.file_location,
                    file_hash_sha256: artifact.file_hash_sha256,
                    file_size: size,
                    mime_type: MIME.from_path(file_out_loc),
                    perceptual_hashes: %{
                      "computed" => Map.get(data, "perceptual_hashes", [])
                    },
                    type: artifact.type
                  }
                end)

              version_map = %{
                status: :complete,
                artifacts: new_artifacts
              }

              {:ok, version} = Material.update_media_version(version, version_map)

              version
          end

          # Track event
          Auditor.log(:archive_success, %{
            media_id: media_id,
            source_url: version.source_url,
            media_version: version
          })

          # Schedule duplicate detection
          Platform.Workers.DuplicateDetector.new(%{
            "media_version_id" => id
          })
          |> Oban.insert!()

          {:ok, version}
        rescue
          val ->
            # Some error happened! Log it and update the media version appropriately.
            Logger.error("Unable to automatically archive media: " <> inspect(val))
            Logger.error(Exception.format_stacktrace())

            Auditor.log(:archive_failed, %{error: inspect(val), version: version})

            if not is_rearchive_request do
              # Update the media version.
              version_map = %{
                status: :error
              }

              # If we're supposed to hide versions on failure, we do so here.
              new_version_map =
                if hide_version_on_failure && version.visibility == :visible do
                  Map.put(version_map, :visibility, :hidden)
                else
                  version_map
                end

              # Actually update the media version
              {:ok, new_version} = Material.update_media_version(version, new_version_map)
            else
              Logger.info(
                "Not updating media version (even though we failed) #{id} because this is a rearchive request."
              )
            end

            {:ok, new_version}
        end

      # Push update to viewers
      Material.broadcast_media_updated(media_id)

      Temp.cleanup()
      result
    else
      _ ->
        Logger.info(
          "Media version #{id} is not pending, and this is not a rearchive request. Skipping."
        )

        {:ok, version}
    end
  end
end
