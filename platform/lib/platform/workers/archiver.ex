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

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_version_id" => id} = args}) do
    %MediaVersion{status: :pending, media_id: media_id} =
      version = Material.get_media_version!(id)

    media = Material.get_media!(media_id)

    hide_version_on_failure = Map.get(args, "hide_version_on_failure", false)

    try do
      # Setup tempfiles for media download
      Temp.track!()
      temp_dir = Temp.mkdir!()

      # Download the media
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

      # Figure out what we downloaded
      [file_name] = File.ls!(temp_dir)
      file_path = Path.join(temp_dir, file_name)
      mime = MIME.from_path(file_path)

      # Process + upload it
      {:ok, identifier, duration, size} = process_uploaded_media(file_path, mime, media)

      # Update the media version to reflect the change
      {:ok, new_version} =
        Material.update_media_version(version, %{
          file_location: identifier,
          file_size: size,
          status: :complete,
          duration_seconds: duration,
          mime_type: mime
        })

      # Track event
      Auditor.log(:archive_success, %{media_id: media_id, source_url: new_version.source_url})

      Updates.change_from_comment(media, Accounts.get_auto_account(), %{
        "explanation" => "✅ Successfully archived the media at #{version.source_url}."
      })
      |> Updates.create_update_from_changeset()

      {:ok, new_version}
    rescue
      val ->
        # Some error happened! Log it and update the media version appropriately.
        Logger.error("Unable to automatically archive media!")
        Auditor.log(:archive_failed, %{error: val, version: version})

        Updates.change_from_comment(media, Accounts.get_auto_account(), %{
          "explanation" =>
            "🛑 Unable to automatically download the media from #{version.source_url}. Either the website is unsupported, or the media is not a video. Someone will need to upload the media manually."
        })
        |> Updates.create_update_from_changeset()

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
  end

  defp process_uploaded_media(path, mime, media) do
    # Preprocesses the given media and uploads it to persistent storage.
    # Returns {:ok, file_path, thumbnail_path, duration}

    identifier = media.slug

    media_path =
      cond do
        String.starts_with?(mime, "image/") -> Temp.path!(%{suffix: ".jpg", prefix: identifier})
        String.starts_with?(mime, "video/") -> Temp.path!(%{suffix: ".mp4", prefix: identifier})
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

    {duration, _} = Integer.parse(out_data["duration"])
    {size, _} = Integer.parse(out_data["size"])

    # Upload to cloud storage
    {:ok, new_path} = Uploads.WatermarkedMediaVersion.store({media_path, media})
    {:ok, _original_path} = Uploads.OriginalMediaVersion.store({path, media})

    {:ok, new_path, duration, size}
  end
end
