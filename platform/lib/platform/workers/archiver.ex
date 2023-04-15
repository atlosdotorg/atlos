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
      "run -v #{temp_dir}:/crawls/ webrecorder/browsertrix-crawler crawl  --generateWACZ --text --screenshot thumbnail,view,fullPage --behaviors autoscroll,autoplay,autofetch,siteSpecific --timeLimit 60 --maxDepth 1 --pageLimit 1 --url"

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

    %{wacz: wacz_file_path, page_metadata: jsonl_contents}
  end

  defp archive_page_videos(from_url, into_folder) do
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

          # Download the media data
          case version.upload_type do
            :user_provided ->
              # Nothing to do here, we already have the media
              # Perhaps take hashes + index

            :direct ->
              # Archive the page, and download the media from it
          end

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
end
