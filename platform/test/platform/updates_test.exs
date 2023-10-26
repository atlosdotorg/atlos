defmodule Platform.UpdatesTest do
  use Platform.DataCase, async: true

  alias Platform.Material
  alias Platform.Updates
  alias Platform.Permissions
  alias Platform.Projects

  import Platform.MaterialFixtures
  import Platform.AccountsFixtures
  import Platform.ProjectsFixtures

  describe "updates" do
    test "Material.update_media_attribute_audited creates an update" do
      admin = admin_user_fixture()
      media = media_fixture(%{project_id: project_fixture(%{}, owner: admin).id})

      assert Enum.empty?(Updates.get_updates_for_media(media))

      assert {:ok, _} =
               Material.update_media_attribute_audited(
                 media,
                 Material.Attribute.get_attribute(:restrictions),
                 admin,
                 %{
                   "explanation" => "Very important explanation",
                   "attr_restrictions" => ["Frozen"]
                 }
               )

      updates = Updates.get_updates_for_media(media)
      assert length(updates) == 1

      assert hd(updates).user_id == admin.id
      assert hd(updates).media_id == media.id
      assert hd(updates).hidden == false
    end

    test "change_update_visibility/2 changes visibility" do
      admin = admin_user_fixture()
      media = media_fixture(%{project_id: project_fixture(%{}, owner: admin).id})

      assert Enum.empty?(Updates.get_updates_for_media(media))

      assert {:ok, _} =
               Material.update_media_attribute_audited(
                 media,
                 Material.Attribute.get_attribute(:restrictions),
                 admin,
                 %{
                   "explanation" => "Very important explanation",
                   "attr_restrictions" => ["Frozen"]
                 }
               )

      assert {:ok, _} =
               Updates.change_from_comment(media, admin, %{
                 "explanation" => "This is my comment."
               })
               |> Updates.create_update_from_changeset()

      updates = Updates.get_updates_for_media(media)

      assert length(updates) == 2

      assert {:ok, _} =
               Updates.change_update_visibility(hd(updates), true)
               |> Updates.update_update_from_changeset()

      modified_updates = Updates.get_updates_for_media(media)
      assert length(modified_updates) == 2
      assert Enum.any?(Enum.map(modified_updates, & &1.hidden))
    end

    test "Permissions.can_view_update?/2 works for admins" do
      admin = admin_user_fixture()
      media = media_fixture(%{project_id: project_fixture(%{}, owner: admin).id})
      user = user_fixture()

      {:ok, _} =
        Projects.create_project_membership(%{
          username: user.username,
          project_id: media.project_id,
          role: :editor
        })

      assert {:ok, _} =
               Material.update_media_attribute_audited(
                 media,
                 Material.Attribute.get_attribute(:restrictions),
                 admin,
                 %{
                   "explanation" => "Very important explanation",
                   "attr_restrictions" => ["Frozen"]
                 }
               )

      updates = Updates.get_updates_for_media(media)
      assert length(updates) == 1

      assert length(Enum.filter(updates, &Permissions.can_view_update?(user, &1))) == 1
      assert length(Enum.filter(updates, &Permissions.can_view_update?(admin, &1))) == 1

      assert {:ok, _} =
               Updates.change_update_visibility(hd(updates), true)
               |> Updates.update_update_from_changeset()

      modified_updates = Updates.get_updates_for_media(media)
      assert length(modified_updates) == 1
      assert Enum.any?(Enum.map(modified_updates, & &1.hidden))

      assert Enum.empty?(Enum.filter(modified_updates, &Permissions.can_view_update?(user, &1)))
      assert length(Enum.filter(modified_updates, &Permissions.can_view_update?(admin, &1))) == 1

      # Quick check to also verify get_updates_for_media excludes hidden
      assert Enum.empty?(Updates.get_updates_for_media(media, true))
    end
  end
end
