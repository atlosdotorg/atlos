defmodule Platform.MaterialTest do
  use Platform.DataCase, async: true

  alias Platform.Projects
  alias Platform.Material
  alias Platform.Updates
  alias Platform.Accounts

  import Platform.MaterialFixtures
  import Platform.AccountsFixtures
  import Platform.ProjectsFixtures

  describe "media" do
    alias Platform.Material.Media

    @invalid_attrs %{attr_description: nil, slug: nil}

    test "list_media/0 returns all media" do
      media = media_fixture()
      listed = Material.list_media()
      assert length(listed) == 1

      id = media.id
      desc = media.attr_description
      assert [%{id: ^id, attr_description: ^desc}] = listed
    end

    test "get_media!/1 returns the media with given id" do
      media = media_fixture()
      assert Material.get_media!(media.id).id == media.id
    end

    test "create_media/1 with valid data creates a media" do
      valid_attrs = %{
        attr_description: "some description",
        attr_sensitive: ["Not Sensitive"],
        project_id: project_fixture().id
      }

      assert {:ok, %Media{} = media} = Material.create_media(valid_attrs)
      assert media.attr_description == "some description"
      assert media.attr_sensitive == ["Not Sensitive"]
    end

    test "create_media/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Material.create_media(@invalid_attrs)
    end

    test "update_media/2 with valid data updates the media" do
      media = media_fixture()
      update_attrs = %{attr_description: "some updated description"}

      assert {:ok, %Media{} = media} = Material.update_media(media, update_attrs)
      assert media.attr_description == "some updated description"
    end

    test "update_media/2 with invalid data returns error changeset" do
      media_id = media_fixture().id
      media = Material.get_media!(media_id)
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
      source_url: nil,
      status: :other
    }

    test "list_media_versions/0 returns all media_versions" do
      media_version = media_version_fixture()
      assert hd(Material.list_media_versions()).id == media_version.id
    end

    test "get_media_version!/1 returns the media_version with given id" do
      media_version = media_version_fixture()
      assert Material.get_media_version!(media_version.id).id == media_version.id
    end

    test "get_media_version_by_source_url/1 returns the media_version with right source URL" do
      media_version = media_version_fixture(%{source_url: "https://atlos.org"})
      results = Material.get_media_versions_by_source_url("https://atlos.org")
      assert length(results) == 1
      assert hd(results).id == media_version.id

      assert Enum.empty?(Material.get_media_versions_by_source_url("https://atlos.org/invalid"))
    end

    test "create_media_version/1 with valid data creates a media_version" do
      valid_attrs = %{
        source_url: "some source_url",
        type: :image
      }

      project = project_fixture()

      assert {:ok, %MediaVersion{} = media_version} =
               Material.create_media_version(project, valid_attrs)

      assert media_version.source_url == "some source_url"
      assert media_version.project_id == project.id
    end

    test "create_media_version/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Material.create_media_version(project_fixture(), @invalid_attrs)
    end

    test "update_media_version/2 with valid data updates the media_version" do
      media_version = media_version_fixture()

      update_attrs = %{
        source_url: "some updated source_url"
      }

      assert {:ok, %MediaVersion{} = media_version} =
               Material.update_media_version(media_version, update_attrs)

      assert media_version.source_url == "some updated source_url"
    end

    test "update_media_version/2 with invalid data returns error changeset" do
      media_version = media_version_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Material.update_media_version(media_version, @invalid_attrs)
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
      media = media_fixture(%{}, for_user: user)
      attribute = Material.Attribute.get_attribute(:sensitive)

      {:ok, updated} =
        Material.update_media_attribute_audited(media, attribute, user, %{
          "explanation" => "Very important explanation",
          "attr_sensitive" => ["Personal Information Visible"]
        })

      assert updated.attr_sensitive == ["Personal Information Visible"]
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
      media = media_fixture(%{project_id: project_fixture(%{}, owner: user).id})
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
      media = media_fixture(%{project_id: project_fixture(%{}, owner: admin).id})
      attribute = Material.Attribute.get_attribute(:restrictions)

      assert {:ok, updated} =
               Material.update_media_attribute_audited(media, attribute, admin, %{
                 "explanation" => "Very important explanation",
                 "attr_restrictions" => ["Frozen"]
               })

      assert updated.attr_restrictions == ["Frozen"]

      user = user_fixture()

      Platform.Projects.create_project_membership(%{
        username: user.username,
        project_id: media.project_id,
        role: :editor
      })

      assert {:error, changeset} =
               Material.update_media_attribute_audited(
                 updated,
                 Material.Attribute.get_attribute(:sensitive),
                 user,
                 %{
                   "explanation" => "Very important explanation",
                   "attr_sensitive" => ["Graphic Violence"]
                 }
               )

      assert !changeset.valid?
      assert String.contains?(errors_on(changeset).attr_sensitive |> Enum.join(), "permission")
    end

    test "normal users cannot edit restricted attributes" do
      admin = admin_user_fixture()
      media = media_fixture(%{project_id: project_fixture(%{}, owner: admin).id})
      user = user_fixture()

      Platform.Projects.create_project_membership(%{
        username: user.username,
        project_id: media.project_id,
        role: :editor
      })

      attribute = Material.Attribute.get_attribute(:restrictions)

      assert {:error, changeset} =
               Material.update_media_attribute_audited(media, attribute, user, %{
                 "explanation" => "Very important explanation",
                 "attr_restrictions" => ["Frozen"]
               })

      assert !changeset.valid?
      assert String.contains?(hd(errors_on(changeset).attr_restrictions), "permission")

      assert {:ok, updated} =
               Material.update_media_attribute_audited(media, attribute, admin, %{
                 "explanation" => "Very important explanation",
                 "attr_restrictions" => ["Frozen"]
               })

      assert updated.attr_restrictions == ["Frozen"]
    end

    test "a muted user cannot edit media" do
      user = user_fixture()
      media = media_fixture(%{}, for_user: user)
      attribute = Material.Attribute.get_attribute(:sensitive)

      assert {:ok, _} =
               Material.update_media_attribute_audited(media, attribute, user, %{
                 "explanation" => "Very important explanation",
                 "attr_sensitive" => ["Personal Information Visible"]
               })

      assert {:ok, modded_user} = Accounts.update_user_admin(user, %{restrictions: [:muted]})

      assert {:error, changeset} =
               Material.update_media_attribute_audited(media, attribute, modded_user, %{
                 "explanation" => "Very important explanation!!!",
                 "attr_sensitive" => ["Not Sensitive"]
               })

      assert String.contains?(hd(errors_on(changeset).attr_sensitive), "permission")
    end

    test "a user can subscribe and unsubscribe to media" do
      user = user_fixture()
      media = media_fixture()

      # Watch the media
      assert 0 == Material.total_subscribed!(media)
      assert nil == Material.get_subscription(media, user)
      assert {:ok, v} = Material.subscribe_user(media, user)
      assert v == Material.get_subscription(media, user)
      assert 1 == Material.total_subscribed!(media)

      Material.unsubscribe_user(media, user)
      assert 0 == Material.total_subscribed!(media)
    end

    test "multiple users can unsubscribe to media" do
      user1 = user_fixture()
      user2 = user_fixture()
      media = media_fixture()

      assert 0 == Material.total_subscribed!(media)
      assert nil == Material.get_subscription(media, user1)
      assert {:ok, w1} = Material.subscribe_user(media, user1)
      assert w1 == Material.get_subscription(media, user1)
      assert 1 == Material.total_subscribed!(media)

      assert {:ok, w2} = Material.subscribe_user(media, user2)
      assert w2 == Material.get_subscription(media, user2)
      assert 2 == Material.total_subscribed!(media)

      assert :ok == Material.unsubscribe_user(media, user1)
      assert 1 == Material.total_subscribed!(media)
    end

    test "list_subscribed_media/1 returns subscribed media" do
      user = user_fixture()
      media1 = media_fixture()
      media2 = media_fixture()

      assert [] == Material.list_subscribed_media(user)
      assert {:ok, _} = Material.subscribe_user(media1, user)
      assert [m1] = Material.list_subscribed_media(user)
      assert m1.id == media1.id
      assert {:ok, _} = Material.subscribe_user(media2, user)
      assert length(Material.list_subscribed_media(user)) == 2
    end

    test "query_media/0 returns all media by default" do
      assert Enum.empty?(Material.query_media())

      Enum.map(1..100, fn _ -> media_fixture() end)
      assert length(Material.query_media()) == 100

      Enum.map(1..100, fn _ -> media_fixture() end)
      assert length(Material.query_media()) == 200
    end

    test "query_media_paginated/1 works with uploaded sorting" do
      assert Enum.empty?(Material.query_media())

      Enum.map(1..25, fn _ -> media_fixture(%{attr_description: "this is earlier"}) end)
      Process.sleep(1000)
      Enum.map(1..25, fn _ -> media_fixture(%{attr_description: "this is later"}) end)

      changeset_desc = Material.MediaSearch.changeset(%{sort: "uploaded_desc"})
      {query_desc, opts_desc} = Material.MediaSearch.search_query(changeset_desc)

      assert hd(Material.query_media_paginated(query_desc, opts_desc).entries).attr_description ==
               "this is later"

      changeset_asc = Material.MediaSearch.changeset(%{sort: "uploaded_asc"})
      {query_asc, opts_asc} = Material.MediaSearch.search_query(changeset_asc)

      assert hd(Material.query_media_paginated(query_asc, opts_asc).entries).attr_description ==
               "this is earlier"
    end

    test "query_media/1 works with basic text search" do
      assert Enum.empty?(Material.query_media())

      Enum.map(1..25, fn _ -> media_fixture() end)
      Enum.map(1..25, fn _ -> media_fixture(%{attr_description: "this is foobar"}) end)

      changeset = Material.MediaSearch.changeset(%{query: "foobar"})
      {query, _} = Material.MediaSearch.search_query(changeset)

      assert length(Material.query_media()) == 50
      assert length(Material.query_media(query)) == 25
    end

    test "query_media/1 works with searching by slug" do
      assert Enum.empty?(Material.query_media())

      Enum.map(1..25, fn _ -> media_fixture() end)
      Enum.map(1..25, fn _ -> media_fixture(%{attr_description: "this is foobar"}) end)
      main = media_fixture()

      changeset = Material.MediaSearch.changeset(%{query: "#{main.slug}"})
      {query, _} = Material.MediaSearch.search_query(changeset)
      assert length(Material.query_media()) == 51
      assert length(Material.query_media(query)) == 1

      project = Platform.ProjectsFixtures.project_fixture(%{code: "HELLO"})

      {:ok, main} = Material.update_media(main, %{project_id: project.id})

      assert length(Material.query_media(query)) == 1

      changeset = Material.MediaSearch.changeset(%{query: "HELLO-#{main.slug}"})

      {query, _} = Material.MediaSearch.search_query(changeset)
      assert length(Material.query_media()) == 51
      assert length(Material.query_media(query)) == 1
    end

    test "query_media/1 works with longer text search" do
      assert Enum.empty?(Material.query_media())

      Enum.map(1..1000, fn _ ->
        media_fixture(%{attr_description: Faker.Lorem.Shakespeare.En.hamlet()})
      end)

      Enum.map(1..3, fn _ ->
        media_fixture(%{
          attr_description:
            (Faker.Lorem.Shakespeare.En.hamlet() |> String.slice(0..100)) <>
              " internet " <> (Faker.Lorem.Shakespeare.En.hamlet() |> String.slice(0..100))
        })
      end)

      changeset = Material.MediaSearch.changeset(%{query: "internet"})
      {query, _} = Material.MediaSearch.search_query(changeset)

      assert length(Material.query_media()) == 1003
      assert length(Material.query_media(query)) == 3
    end

    test "MediaSearch.filter_viewable/2 excludes hidden media" do
      user = user_fixture()
      admin = admin_user_fixture()

      project = project_fixture()

      Projects.create_project_membership(%{
        username: user.username,
        project_id: project.id,
        role: :viewer
      })

      Projects.create_project_membership(%{
        username: admin.username,
        project_id: project.id,
        role: :owner
      })

      Enum.map(1..50, fn _ ->
        media_fixture(%{project_id: project.id})
      end)

      Enum.map(1..10, fn _ ->
        media_fixture(%{project_id: project.id})
      end)
      |> Enum.map(
        &Material.update_media_attribute(&1, Material.Attribute.get_attribute(:restrictions), %{
          attr_restrictions: ["Hidden"]
        })
      )

      assert length(Material.query_media()) == 60
      assert length(Material.MediaSearch.filter_viewable(user) |> Material.query_media()) == 50
      assert length(Material.MediaSearch.filter_viewable(admin) |> Material.query_media()) == 60
    end

    test "MediaSearch.filter_viewable/2 and text search compose properly" do
      user = user_fixture()
      admin = admin_user_fixture()

      project = project_fixture()

      Projects.create_project_membership(%{
        username: user.username,
        project_id: project.id,
        role: :editor
      })

      Projects.create_project_membership(%{
        username: admin.username,
        project_id: project.id,
        role: :owner
      })

      Enum.map(1..50, fn _ ->
        media_fixture(%{attr_description: "description is foo bar!", project_id: project.id})
      end)

      Enum.map(1..50, fn _ ->
        media_fixture(%{attr_description: "description is bing bong!", project_id: project.id})
      end)

      (Enum.map(1..10, fn _ ->
         media_fixture(%{attr_description: "description is foo bar!", project_id: project.id})
       end) ++
         Enum.map(1..10, fn _ ->
           media_fixture(%{attr_description: "description is bing bong!", project_id: project.id})
         end))
      |> Enum.map(
        &Material.update_media_attribute(&1, Material.Attribute.get_attribute(:restrictions), %{
          attr_restrictions: ["Hidden"]
        })
      )

      assert length(Material.query_media()) == 120

      {query, _} =
        Material.MediaSearch.search_query(Material.MediaSearch.changeset(%{query: "bing bong"}))

      assert length(
               query
               |> Material.MediaSearch.filter_viewable(admin)
               |> Material.query_media()
             ) == 60

      assert length(query |> Material.MediaSearch.filter_viewable(user) |> Material.query_media()) ==
               50
    end

    test "query_media_paginated/0 paginates" do
      assert Enum.empty?(Material.query_media_paginated().entries)

      Enum.map(1..100, fn _ -> media_fixture() end)

      assert length(Material.query_media_paginated().entries) == 50
      assert length(Material.query_media_paginated(Material.Media, limit: 100).entries) == 100
    end

    test "values_of_attribute/1 gets all values of the attribute" do
      attr = Material.Attribute.get_attribute(:tags)
      assert Material.get_values_of_attribute(attr) == []

      {:ok, _} =
        Material.update_media_attribute(
          media_fixture(),
          Material.Attribute.get_attribute(:tags),
          %{
            attr_tags: ["tag 1", "tag 2"]
          }
        )

      {:ok, _} =
        Material.update_media_attribute(
          media_fixture(),
          Material.Attribute.get_attribute(:tags),
          %{
            attr_tags: ["tag 3"]
          }
        )

      real_vals = ["tag 1", "tag 2", "tag 3"]
      found_vals = Material.get_values_of_attribute(attr)

      assert length(real_vals) == length(real_vals)
      assert Enum.all?(real_vals, &Enum.member?(found_vals, &1))
    end
  end
end
