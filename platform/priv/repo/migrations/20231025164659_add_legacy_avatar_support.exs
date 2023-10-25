defmodule Platform.Repo.Migrations.AddLegacyAvatarSupport do
  use Ecto.Migration

  def change do
    # Set the value of the `profile_photo_file` column to the empty string for all users
    alter table("users") do
      add :has_legacy_avatar, :boolean, default: false, null: false
    end

    execute "update users set has_legacy_avatar = true where profile_photo_file is not null and profile_photo_file != ''"
  end
end
