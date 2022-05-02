defmodule Platform.Uploads.Avatar do
  use Arc.Definition

  @versions [:original, :thumb]

  def transform(:thumb, _) do
    {:convert, "-strip -thumbnail 100x100^ -gravity center -extent 100x100"}
  end

  def filename(version, {file, scope}) do
    file_name = Path.basename(file.file_name, Path.extname(file.file_name))
    "#{scope.id}_#{version}"
  end

  def default_url(version) do
    Platform.Endpoint.url() <> "/images/default_profile.jpg"
  end

  def storage_dir(version, {file, scope}) do
    "avatars/#{scope.id}"
  end
end

defmodule Platform.Uploads.WatermarkedMediaVersion do
  use Arc.Definition

  alias Platform.Utils

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

  def filename(version, {file, scope}) do
    "#{file.file_name}-#{version}"
  end

  def storage_dir(version, {file, scope}) do
    "media/#{scope.slug}/watermarked/"
  end
end

defmodule Platform.Uploads.OriginalMediaVersion do
  use Arc.Definition

  @versions [:original]

  def filename(version, {file, scope}) do
    "#{file.file_name}-#{version}"
  end

  def storage_dir(version, {file, scope}) do
    "media/#{scope.slug}/original/"
  end
end
