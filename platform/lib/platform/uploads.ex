defmodule Platform.Uploads.Avatar do
  use Waffle.Definition

  @versions [:original, :thumb]

  def transform(:thumb, _) do
    {:convert, "-strip -thumbnail 100x100^ -gravity center -extent 100x100"}
  end

  def filename(version, {_file, scope}) do
    if scope.has_legacy_avatar do
      "#{scope.deprecated_integer_id}_#{version}"
    else
      if is_nil(scope.avatar_uuid) do
        "#{scope.id}_#{version}"
      else
        "#{scope.id}_#{scope.avatar_uuid}_#{version}}"
      end
    end
  end

  def default_url(_version) do
    "/images/default_profile.jpg"
  end

  def storage_dir(_version, {_file, scope}) do
    if scope.has_legacy_avatar do
      "avatars/#{scope.deprecated_integer_id}"
    else
      "avatars/#{scope.id}"
    end
  end

  def s3_object_headers(_version, {file, _scope}) do
    [content_type: MIME.from_path(file.file_name)]
  end
end

defmodule Platform.Uploads.WatermarkedMediaVersion do
  use Waffle.Definition

  @versions [:original, :thumb]

  def transform(:thumb, _) do
    {:ffmpeg,
     fn input, output ->
       if String.ends_with?(input, ".png") || String.ends_with?(input, ".jpg") ||
            String.ends_with?(input, ".jpeg") do
         "-i #{input} -f apng #{output}"
       else
         "-i #{input} -ss 00:00:01.000 -vframes 1 -f apng #{output}"
       end
     end, :png}
  end

  def filename(version, {file, _scope}) do
    "#{file.file_name}-#{version}"
  end

  def storage_dir(_version, {_file, scope}) do
    "media/#{scope.slug}/watermarked/"
  end

  def s3_object_headers(_version, {file, _scope}) do
    [content_type: MIME.from_path(file.file_name)]
  end
end

defmodule Platform.Uploads.MediaVersionArtifact do
  use Waffle.Definition

  @versions [:original, :thumbnail]

  def transform(:thumbnail, {file, _}) do
    mime = MIME.from_path(file.file_name)

    cond do
      Platform.Utils.is_processable_image(mime) ->
        {:ffmpeg,
         fn input, output ->
           "-i #{input} -f apng #{output}"
         end, :png}

      String.starts_with?(mime, "video/") ->
        {:ffmpeg,
         fn input, output ->
           "-i #{input} -ss 00:00:01.000 -vframes 1 -f apng #{output}"
         end, :png}

      true ->
        :skip
    end
  end

  def filename(version, {file, _scope}) do
    "#{version}-#{file.file_name}"
  end

  def storage_dir(_version, {_file, scope}) do
    "artifacts/#{scope.id}/"
  end

  def s3_object_headers(_version, {file, _scope}) do
    [content_type: MIME.from_path(file.file_name)]
  end
end

defmodule Platform.Uploads.UpdateAttachment do
  use Waffle.Definition

  @versions [:original]

  def filename(version, {file, _scope}) do
    "#{file.file_name}-#{version}"
  end

  def storage_dir(_version, {_file, scope}) do
    "attachments/#{scope.slug}/"
  end

  def s3_object_headers(_version, {file, _scope}) do
    [content_type: MIME.from_path(file.file_name)]
  end
end

defmodule Platform.Uploads.ExportFile do
  use Waffle.Definition

  # Define versions
  @versions [:original]

  # Define storage directory based on user ID and export type
  def storage_dir(_version, {_file, scope}) do
    "exports/#{scope.user_id}/#{scope.export_type}"
  end

  # Generate unique filename with date
  def filename(_version, {_file, scope}) do
    date_str = Date.utc_today() |> Date.to_string()
    "#{scope.prefix}-#{date_str}-#{scope.suffix}"
  end

  # Set appropriate content type headers
  def s3_object_headers(_version, {_file, scope}) do
    [content_type: scope.content_type]
  end
end
