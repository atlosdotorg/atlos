defmodule Platform.Uploads.Avatar do
  use Waffle.Definition

  @versions [:original, :thumb]

  def transform(:thumb, _) do
    {:convert, "-strip -thumbnail 100x100^ -gravity center -extent 100x100"}
  end

  def filename(version, {_file, scope}) do
    "#{scope.id}_#{version}"
  end

  def default_url(_version) do
    "/images/default_profile.jpg"
  end

  def storage_dir(_version, {_file, scope}) do
    "avatars/#{scope.id}"
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

  @versions [:original]

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
