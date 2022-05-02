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
