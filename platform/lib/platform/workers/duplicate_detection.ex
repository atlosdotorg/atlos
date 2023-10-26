defmodule Platform.Workers.DuplicateDetector do
  alias Platform.Material

  @hamming_threshold 15

  require Logger

  use Oban.Worker,
    queue: :duplicate_detection,
    priority: 3

  def get_hashes(media_version) do
    Enum.map(media_version.artifacts, fn artifact ->
      (artifact.perceptual_hashes || %{})
      |> Map.get("computed", [])
      |> Enum.map(fn %{"hash" => hash} -> hash end)
    end)
    |> List.flatten()
  end

  def hamming_distance(hash1, hash2) do
    # Calculates the hamming distance between the base64 encodings of two perceptual hashes.
    with {:ok, binary1} <- Base.decode64(hash1),
         {:ok, binary2} <- Base.decode64(hash2) do
      Logger.debug("Calculating the hamming distance between #{hash1} and #{hash2}")

      if byte_size(binary1) == byte_size(binary2) do
        dist =
          Enum.zip_with(:binary.bin_to_list(binary1), :binary.bin_to_list(binary2), fn a, b ->
            for(<<bit::1 <- :binary.encode_unsigned(Bitwise.bxor(a, b))>>,
              do: bit
            )
            |> Enum.sum()
          end)
          |> Enum.sum()

        Logger.debug("Hamming distance between #{hash1} and #{hash2} : #{dist}")
        {:ok, dist}
      else
        Logger.debug("Unequal length!")
        {:error, :unequal_length}
      end
    else
      _ -> {:error, :invalid_base64}
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_version_id" => id} = _args}) do
    version = Material.get_media_version!(id)
    media = Material.get_media!(version.media_id) |> Platform.Repo.preload([:project, :versions])

    Logger.info("Checking for duplicate artifacts: #{media.slug} (version id=#{version.id})")

    # First, we find all the perceptual hashes for the media version.
    hashes = get_hashes(version)

    # Next, we search for media versions that have perceptual hashes that are similar to these
    # perceptual hashes.
    candidate_media =
      Enum.map(hashes, fn hash ->
        {query, _} =
          Platform.Material.MediaSearch.search_query(
            Platform.Material.MediaSearch.changeset(%{
              "project_id" => media.project_id
            })
          )

        Material.query_media(query)
      end)
      |> List.flatten()
      |> Enum.uniq_by(& &1.id)
      |> Enum.filter(
        &(&1.id != version.media_id and
            &1.deleted == false and not Material.Media.has_restrictions(&1))
      )

    Logger.debug("Found #{Enum.count(candidate_media)} candidate media")

    results =
      candidate_media
      |> Enum.map(& &1.versions)
      |> List.flatten()
      |> Enum.filter(&(&1.visibility == :visible))
      |> Enum.filter(fn version ->
        sub_hashes = get_hashes(version)

        Enum.any?(sub_hashes, fn sub_hash ->
          Enum.any?(
            hashes,
            fn hash ->
              case hamming_distance(sub_hash, hash) do
                {:ok, dist} -> dist <= @hamming_threshold
                _ -> false
              end
            end
          )
        end)
      end)

    Logger.info("Found #{Enum.count(results)} potential duplicates for #{media.slug}")

    # If we found any results, we go through and check which media version matched. We then verify that
    # the media version is visible.
    if Enum.empty?(results) do
      Logger.info("No duplicates found for #{media.slug}")
    else
      Logger.info("Found duplicates for #{media.slug}: #{Enum.map(results, & &1.id)}")

      # We then post a comment on the media version with the results.
      Platform.Updates.post_bot_comment(
        media,
        "Source material in [[#{Platform.Material.get_human_readable_media_version_name(media, version)}]] may have already been added to incidents in this project. Please check the following source material for possible duplicates: #{Enum.map(results, fn v -> "[[#{Platform.Material.get_human_readable_media_version_name(Enum.find(candidate_media, &(&1.id == v.media_id)), v)}]]" end) |> Enum.join(", ")}"
      )
    end

    :ok
  end
end
