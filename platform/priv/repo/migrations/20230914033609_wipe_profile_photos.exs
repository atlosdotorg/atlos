defmodule Platform.Repo.Migrations.WipeProfilePhotos do
  use Ecto.Migration

  def change do
    # Set the value of the `profile_photo_file` column to the empty string for all users
    execute "UPDATE users SET profile_photo_file = ''", []
  end
end
