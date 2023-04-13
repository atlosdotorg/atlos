defmodule Platform.Workers.Archiver do
  alias Platform.Material
  alias Platform.Material.MediaVersion
  alias Platform.Auditor
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

  def archive_page(url) do
    temp_dir = Temp.mkdir!()

    # Browsertrix is a docker container that crawls a page and generates a WACZ file.
    # It already has good support for crawling pages with media, so we use it here.
    # We also use it to generate thumbnails, which we'll use for the preview image.
    # It also generates a text index of the page, and a full-page screenshot.
    # It has a 90 second timeout to prevent it from hanging on pages that take too long to load.
    command =
      "run -v #{temp_dir}:/crawls/ webrecorder/browsertrix-crawler crawl  --generateWACZ --text --screenshot thumbnail,view,fullPage --behaviors autoscroll,autoplay,autofetch,siteSpecific --url"

    {_, 0} = System.cmd("docker", String.split(command) ++ [url], into: IO.stream())

    # The crawl folder is temp_dir/collections/<first_file>/
    collections_folder = Path.join(temp_dir, "collections")
    crawl_folder = Path.join(collections_folder, File.ls!(collections_folder) |> List.first())
    pages_jsonl = Path.join(crawl_folder, "pages/pages.jsonl")

    wacz_file_name =
      File.ls!(crawl_folder) |> Enum.filter(&String.ends_with?(&1, ".wacz")) |> List.first()

    wacz_file_path = Path.join(crawl_folder, wacz_file_name)

    jsonl_contents =
      File.read!(pages_jsonl)
      |> String.split("\n")
      |> Enum.map(&String.trim(&1))
      |> Enum.filter(&(String.length(&1) != 0))
      |> Enum.map(&Jason.decode!/1)

    # We need to grab the pages.jsonl file, and the WACZ file. The pages.jsonl file contains the metadata for the page.
    IO.puts("Got files: #{inspect(File.ls!(temp_dir))} (in dir #{inspect(temp_dir)})")
    IO.puts("Does wacz exist? #{File.exists?(wacz_file_path)}")
    dbg(jsonl_contents)

    %{wacz: wacz_file_path, page_metadata: jsonl_contents}
  end

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

  defp extract_media_from_url(from_url, into_folder) do
    {_, 0} =
      System.cmd(
        "yt-dlp",
        [
          from_url,
          "-o",
          Path.join(into_folder, "out.%(ext)s"),
          "--max-filesize",
          "500m",
          "--merge-output-format",
          "mp4"
        ],
        into: IO.stream()
      )
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_version_id" => id} = args}) do
    Logger.info("Archiving media version #{id}...")
    version = Material.get_media_version!(id)

    with %MediaVersion{status: :pending, media_id: media_id} <- version do
      media = Material.get_media!(media_id)

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

          # Setup tempfiles for media download
          temp_dir = Temp.mkdir!()

          # Download the media (either from S3 for user-provided files, from the original source, or, if we're cloning from an existing media version, then from that media version)
          case version.upload_type do
            :user_provided ->
              Logger.info("Archiving media version #{id}... (downloading from S3)")

              # If we're merging, grab the original version from the source rather than from the given media version
              url =
                case Map.get(args, "clone_from_media_version_id") do
                  nil ->
                    Logger.info(
                      "Archiving media version #{id}... (downloading from S3) (not cloning)"
                    )

                    Uploads.OriginalMediaVersion.url({version.file_location, media},
                      signed: true
                    )

                  id ->
                    Logger.info(
                      "Archiving media version #{id}... (downloading from S3) (cloning from #{id})"
                    )

                    source_version = Material.get_media_version!(id)

                    Uploads.OriginalMediaVersion.url(
                      {source_version.file_location,
                       Material.get_media!(source_version.media_id)},
                      signed: true
                    )
                end

              Logger.info("Archiving media version #{id}... (downloading from S3) (url: #{url})")

              {_, 0} = download_file(url, Path.join(temp_dir, version.file_location))

            :direct ->
              # When merging media we pulled from the source, we just re-pull, hence why there are no additional conditions here
              {_, 0} = extract_media_from_url(version.source_url, temp_dir)
          end

          # Figure out what we downloaded
          [file_name] = File.ls!(temp_dir)
          file_path = Path.join(temp_dir, file_name)
          mime = MIME.from_path(file_path)

          Logger.info(
            "Archiving media version #{id}... (got file #{file_name} with mime #{mime})"
          )

          # Process + upload it (only store original if upload_type is direct/not user provided, *or* we're cloning)
          {:ok, identifier, duration, size, hash} =
            process_uploaded_media(
              file_path,
              mime,
              media,
              version,
              version.upload_type == :direct or
                not is_nil(Map.get(args, "clone_from_media_version_id"))
            )

          Logger.info(
            "Got identifier #{identifier}, duration #{duration}, size #{size}, hash #{hash}"
          )

          # Update the media version to reflect the change
          {:ok, new_version} =
            Material.update_media_version(version, %{
              file_location: identifier,
              file_size: size,
              status: :complete,
              duration_seconds: duration,
              mime_type: mime,
              hashes: %{sha256: hash}
            })

          # Track event
          Auditor.log(:archive_success, %{
            media_id: media_id,
            source_url: new_version.source_url,
            media_version: new_version
          })

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

      # Push update to viewers
      Material.broadcast_media_updated(media_id)

      Temp.cleanup()
      result
    else
      _ ->
        Logger.error("Media version #{id} is not pending, skipping.")
        {:ok, version}
    end
  end

  @doc """
  Process the media at the given path. Also called by the manual media uploader.
  """
  def process_uploaded_media(path, _mime, media, _version, store_original \\ true) do
    # Preprocesses the given media and uploads it to persistent storage.
    # Returns {:ok, file_path, thumbnail_path, duration}

    {:ok, out_data} = FFprobe.format(path)

    hash = hash_sha256_file(path)

    {duration, _} = Integer.parse(out_data["duration"] || "0")
    {size, _} = Integer.parse(out_data["size"])

    # Upload to cloud storage
    {:ok, new_path} = Uploads.WatermarkedMediaVersion.store({path, media})

    if store_original do
      {:ok, _original_path} = Uploads.OriginalMediaVersion.store({path, media})
    end

    {:ok, new_path, duration, size, hash}
  end
end
