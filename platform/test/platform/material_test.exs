defmodule Platform.MaterialTest do
  use Platform.DataCase

  alias Platform.Material

  describe "media" do
    alias Platform.Material.Media

    import Platform.MaterialFixtures

    @invalid_attrs %{description: nil, slug: nil}

    test "list_media/0 returns all media" do
      media = media_fixture()
      assert Material.list_media() == [media]
    end

    test "get_media!/1 returns the media with given id" do
      media = media_fixture()
      assert Material.get_media!(media.id) == media
    end

    test "create_media/1 with valid data creates a media" do
      valid_attrs = %{description: "some description", slug: "some slug"}

      assert {:ok, %Media{} = media} = Material.create_media(valid_attrs)
      assert media.description == "some description"
      assert media.slug == "some slug"
    end

    test "create_media/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Material.create_media(@invalid_attrs)
    end

    test "update_media/2 with valid data updates the media" do
      media = media_fixture()
      update_attrs = %{description: "some updated description", slug: "some updated slug"}

      assert {:ok, %Media{} = media} = Material.update_media(media, update_attrs)
      assert media.description == "some updated description"
      assert media.slug == "some updated slug"
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
end
