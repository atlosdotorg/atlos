defmodule Platform.MaterialTest do
  use Platform.DataCase

  alias Platform.Material
  alias Platform.Updates

  import Platform.MaterialFixtures
  import Platform.AccountsFixtures

  describe "media" do
    alias Platform.Material.Media

    @invalid_attrs %{description: nil, slug: nil}

    test "list_media/0 returns all media" do
      media = media_fixture()
      listed = Material.list_media()
      assert length(listed) == 1

      id = media.id
      desc = media.description
      assert [%{id: ^id, description: ^desc}] = listed
    end

    test "get_media!/1 returns the media with given id" do
      media = media_fixture()
      assert Material.get_media!(media.id) == media
    end

    test "create_media/1 with valid data creates a media" do
      valid_attrs = %{
        description: "some description",
        attr_sensitive: ["Not Sensitive"]
      }

      assert {:ok, %Media{} = media} = Material.create_media(valid_attrs)
      assert media.description == "some description"
      assert media.attr_sensitive == ["Not Sensitive"]
    end

    test "create_media/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Material.create_media(@invalid_attrs)
    end

    test "update_media/2 with valid data updates the media" do
      media = media_fixture()
      update_attrs = %{description: "some updated description"}

      assert {:ok, %Media{} = media} = Material.update_media(media, update_attrs)
      assert media.description == "some updated description"
    end

    test "update_media/2 with invalid data returns error changeset" do
      media = media_fixture()
      assert {:error, %Ecto.Changeset{}} = Material.update_media(media, @invalid_attrs)
      assert media == Material.get_media!(media.id)
    end

    test "delete_media/1 deletes the media" do
      media = media_fixture()
      assert {:ok, %Media{}} = Material.delete_media(media)
      assert_raise Ecto.NoResultsError, fn -> Material.get_media!(media.id) end
    end

    test "change_media/1 returns a media changeset" do
      media = media_fixture()
      assert %Ecto.Changeset{} = Material.change_media(media)
    end
  end

  describe "media_versions" do
    alias Platform.Material.MediaVersion

    @invalid_attrs %{
      file_location: nil,
      file_size: nil,
      perceptual_hash: nil,
      source_url: nil,
      type: nil
    }

    test "list_media_versions/0 returns all media_versions" do
      media_version = media_version_fixture()
      assert Material.list_media_versions() == [media_version]
    end

    test "get_media_version!/1 returns the media_version with given id" do
      media_version = media_version_fixture()
      assert Material.get_media_version!(media_version.id) == media_version
    end

    test "create_media_version/1 with valid data creates a media_version" do
      valid_attrs = %{
        file_location: "some file_location",
        file_size: 42,
        perceptual_hash: "some perceptual_hash",
        source_url: "some source_url",
        type: :image,
        duration_seconds: 30,
        mime_type: "image/png",
        client_name: "upload.png",
        thumbnail_location: "somewhere"
      }

      media = media_fixture()

      assert {:ok, %MediaVersion{} = media_version} =
               Material.create_media_version(media, valid_attrs)

      assert media_version.file_location == "some file_location"
      assert media_version.file_size == 42
      assert media_version.perceptual_hash == "some perceptual_hash"
      assert media_version.source_url == "some source_url"
    end

    test "create_media_version/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Material.create_media_version(media_fixture(), @invalid_attrs)
    end

    test "update_media_version/2 with valid data updates the media_version" do
      media_version = media_version_fixture()

      update_attrs = %{
        file_location: "some updated file_location",
        file_size: 43,
        perceptual_hash: "some updated perceptual_hash",
        source_url: "some updated source_url",
        duration_seconds: 30,
        mime_type: "image/png",
        client_name: "upload.png",
        thumbnail_location: "somewhere"
      }

      assert {:ok, %MediaVersion{} = media_version} =
               Material.update_media_version(media_version, update_attrs)

      assert media_version.file_location == "some updated file_location"
      assert media_version.file_size == 43
      assert media_version.perceptual_hash == "some updated perceptual_hash"
      assert media_version.source_url == "some updated source_url"
    end

    test "update_media_version/2 with invalid data returns error changeset" do
      media_version = media_version_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Material.update_media_version(media_version, @invalid_attrs)

      assert media_version == Material.get_media_version!(media_version.id)
    end

    test "delete_media_version/1 deletes the media_version" do
      media_version = media_version_fixture()
      assert {:ok, %MediaVersion{}} = Material.delete_media_version(media_version)
      assert_raise Ecto.NoResultsError, fn -> Material.get_media_version!(media_version.id) end
    end

    test "change_media_version/1 returns a media_version changeset" do
      media_version = media_version_fixture()
      assert %Ecto.Changeset{} = Material.change_media_version(media_version)
    end

    test "a user modifying an attribute (audited) creates an update" do
      user = user_fixture()
      media = media_fixture()
      attribute = Material.Attribute.get_attribute(:sensitive)

      {:ok, updated} =
        Material.update_media_attribute_audited(media, attribute, user, %{
          "explanation" => "Very important explanation",
          "attr_sensitive" => ["Threatens Civilian Safety"]
        })

      assert updated.attr_sensitive == ["Threatens Civilian Safety"]
      assert [update = %Updates.Update{}] = Updates.get_updates_for_media(media)
      assert update.media_id == media.id
      assert update.user_id == user.id
      assert update.explanation == "Very important explanation"
    end

    test "a user modifying a protected attribute (audited) fails" do
      user = user_fixture()
      media = media_fixture()
      attribute = Material.Attribute.get_attribute(:restrictions)

      assert {:error, changeset} =
               Material.update_media_attribute_audited(media, attribute, user, %{
                 "explanation" => "Very important explanation",
                 "attr_restrictions" => ["Frozen"]
               })

      assert !changeset.valid?
      assert String.contains?(hd(errors_on(changeset).attr_restrictions), "permission")
    end

    test "an admin modifying a protected attribute (audited) works" do
      user = admin_user_fixture()
      media = media_fixture()
      attribute = Material.Attribute.get_attribute(:restrictions)

      assert {:ok, updated} =
               Material.update_media_attribute_audited(media, attribute, user, %{
                 "explanation" => "Very important explanation",
                 "attr_restrictions" => ["Frozen"]
               })

      assert updated.attr_restrictions == ["Frozen"]
    end

    test "a user cannot edit frozen media" do
      admin = admin_user_fixture()
      media = media_fixture()
      attribute = Material.Attribute.get_attribute(:restrictions)

      assert {:ok, updated} =
               Material.update_media_attribute_audited(media, attribute, admin, %{
                 "explanation" => "Very important explanation",
                 "attr_restrictions" => ["Frozen"]
               })

      assert updated.attr_restrictions == ["Frozen"]

      user = user_fixture()

      assert {:error, changeset} =
               Material.update_media_attribute_audited(media, attribute, user, %{
                 "explanation" => "Very important explanation",
                 "attr_sensitive" => ["Graphic Violence"]
               })

      assert !changeset.valid?
      assert String.contains?(hd(errors_on(changeset).attr_restrictions), "permission")
    end

    test "a user can watch and unwatch media" do
      user = user_fixture()
      media = media_fixture()

      # Watch the media
      assert 0 == Material.total_watching!(media)
      assert nil == Material.get_watching(media, user)
      assert {:ok, v} = Material.watch_media(media, user)
      assert v == Material.get_watching(media, user)
      assert 1 == Material.total_watching!(media)

      Material.unwatch_media(media, user)
      assert 0 == Material.total_watching!(media)
    end

    test "multiple users can unwatch media" do
      user1 = user_fixture()
      user2 = user_fixture()
      media = media_fixture()

      assert 0 == Material.total_watching!(media)
      assert nil == Material.get_watching(media, user1)
      assert {:ok, w1} = Material.watch_media(media, user1)
      assert w1 == Material.get_watching(media, user1)
      assert 1 == Material.total_watching!(media)

      assert {:ok, w2} = Material.watch_media(media, user2)
      assert w2 == Material.get_watching(media, user2)
      assert 2 == Material.total_watching!(media)

      assert {:ok, _} = Material.unwatch_media(media, user1)
      assert 1 == Material.total_watching!(media)
    end

    test "list_watched_media/1 returns watched media" do
      user = user_fixture()
      media1 = media_fixture()
      media2 = media_fixture()

      assert [] == Material.list_watched_media(user)
      assert {:ok, _} = Material.watch_media(media1, user)
      assert [m1] = Material.list_watched_media(user)
      assert m1.id == media1.id
      assert {:ok, _} = Material.watch_media(media2, user)
      assert length(Material.list_watched_media(user)) == 2
    end
  end
end
