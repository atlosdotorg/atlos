defmodule Platform.Workers.Archiver do
  alias Platform.Material
  alias Platform.Material.MediaVersion
  alias Platform.Updates
  alias Platform.Auditor
  alias Platform.Accounts
  alias Platform.Uploads

  require Logger

  use Oban.Worker,
    queue: :media_archival,
    priority: 3

  defp hash_sha256_file(file_path) do
    File.stream!(file_path)
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16(case: :lower)
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_version_id" => id} = args}) do
    %MediaVersion{status: :pending, media_id: media_id} =
      version = Material.get_media_version!(id)

    media = Material.get_media!(media_id)

    hide_version_on_failure = Map.get(args, "hide_version_on_failure", false)

    # Cleanup any existing tempfiles. (The worker is a long-running task.)
    # In case we haven't already
    Temp.track!()
    Temp.cleanup()

    result =
      try do
        # Submit to the Internet Archive for archival
        Material.submit_for_external_archival(version)

        # Setup tempfiles for media download
        temp_dir = Temp.mkdir!()

        # Download the media (either from S3 for user-provided files, or from the original source)
        case version.upload_type do
          :user_provided ->
            url = Uploads.OriginalMediaVersion.url({version.file_location, media}, signed: true)

            {_, 0} =
              System.cmd(
                "curl",
                [
                  "-L",
                  url,
                  "-o",
                  Path.join(temp_dir, version.file_location)
                ],
                into: IO.stream()
              )

          :direct ->
            {_, 0} =
              System.cmd(
                "yt-dlp",
                [
                  version.source_url,
                  "-o",
                  Path.join(temp_dir, "out.%(ext)s"),
                  "--max-filesize",
                  "500m",
                  "--merge-output-format",
                  "mp4"
                ],
                into: IO.stream()
              )
        end

        # Figure out what we downloaded
        [file_name] = File.ls!(temp_dir)
        file_path = Path.join(temp_dir, file_name)
        mime = MIME.from_path(file_path)

        # Process + upload it (only store original if upload_type is direct/not user provided)
        {:ok, identifier, duration, size, watermarked_hash, original_hash} =
          process_uploaded_media(file_path, mime, media, version, version.upload_type == :direct)

        # Update the media version to reflect the change
        {:ok, new_version} =
          Material.update_media_version(version, %{
            file_location: identifier,
            file_size: size,
            status: :complete,
            duration_seconds: duration,
            mime_type: mime,
            hashes: %{original_sha256: original_hash, watermarked_sha256: watermarked_hash}
          })

        # Track event
        Auditor.log(:archive_success, %{
          media_id: media_id,
          source_url: new_version.source_url,
          media_version: new_version
        })

        # Push update to viewers
        Material.broadcast_media_updated(media_id)

        {:ok, new_version}
      rescue
        val ->
          # Some error happened! Log it and update the media version appropriately.
          Logger.error("Unable to automatically archive media: " <> inspect(val))
          Logger.error(Exception.format_stacktrace())

          Auditor.log(:archive_failed, %{error: inspect(val), version: version})

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

          {:ok, new_version}
      end

    Temp.cleanup()
    result
  end

  @doc """
  Process the media at the given path. Also called by the manual media uploader.
  """
  def process_uploaded_media(path, mime, media, version, store_original \\ true) do
    # Preprocesses the given media and uploads it to persistent storage.
    # Returns {:ok, file_path, thumbnail_path, duration}

    identifier = Material.get_human_readable_media_version_name(media, version)

    media_path =
      cond do
        String.starts_with?(mime, "image/") -> Temp.path!(%{suffix: ".jpg", prefix: media.slug})
        String.starts_with?(mime, "video/") -> Temp.path!(%{suffix: ".mp4", prefix: media.slug})
      end

    font_path =
      System.get_env(
        "WATERMARK_FONT_PATH",
        Path.join(:code.priv_dir(:platform), "static/fonts/iosevka-bold.ttc")
      )

    IO.puts("Loading font from #{font_path}; file exists? #{File.exists?(font_path)}")

    process_command =
      FFmpex.new_command()
      |> FFmpex.add_input_file(path)
      |> FFmpex.add_output_file(media_path)
      |> FFmpex.add_file_option(
        FFmpex.Options.Video.option_vf(
          "drawtext=text='#{identifier}':x=20:y=20:fontfile=#{font_path}:fontsize=24:fontcolor=white:box=1:boxcolor=black@0.25:boxborderw=5"
        )
      )

    {:ok, _} = FFmpex.execute(process_command)

    {:ok, out_data} = FFprobe.format(media_path)

    watermarked_hash = hash_sha256_file(media_path)
    original_hash = hash_sha256_file(path)

    {duration, _} = Integer.parse(out_data["duration"])
    {size, _} = Integer.parse(out_data["size"])

    # Upload to cloud storage
    {:ok, new_path} = Uploads.WatermarkedMediaVersion.store({media_path, media})

    if store_original do
      {:ok, _original_path} = Uploads.OriginalMediaVersion.store({path, media})
    end

    {:ok, new_path, duration, size, watermarked_hash, original_hash}
  end
end
