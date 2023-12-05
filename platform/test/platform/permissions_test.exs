defmodule Platform.PermissionsTest do
  use Platform.DataCase, async: true

  alias Platform.Projects
  alias Platform.Permissions
  alias Platform.ProjectsFixtures
  alias Platform.AccountsFixtures
  alias Platform.MaterialFixtures

  setup do
    project = ProjectsFixtures.project_fixture()
    user = AccountsFixtures.user_fixture()
    owner = AccountsFixtures.user_fixture()
    manager = AccountsFixtures.user_fixture()
    editor = AccountsFixtures.user_fixture()

    Projects.create_project_membership(%{
      project_id: project.id,
      username: owner.username,
      role: :owner
    })

    Projects.create_project_membership(%{
      project_id: project.id,
      username: manager.username,
      role: :manager
    })

    Projects.create_project_membership(%{
      project_id: project.id,
      username: editor.username,
      role: :editor
    })

    media = MaterialFixtures.media_fixture(%{project_id: project.id})

    {:ok,
     project: project, user: user, owner: owner, manager: manager, editor: editor, media: media}
  end

  describe "permissions" do
    test "can_view_project?/2", context do
      assert Permissions.can_view_project?(context.owner, context.project)
      refute Permissions.can_view_project?(context.user, context.project)
    end

    test "can_create_project?/1", context do
      assert Permissions.can_create_project?(context.user)
    end

    test "can_edit_project_metadata?/2", context do
      assert Permissions.can_edit_project_metadata?(context.owner, context.project)
      refute Permissions.can_edit_project_metadata?(context.editor, context.project)
    end

    test "can_view_project_deleted_media?/2", context do
      assert Permissions.can_view_project_deleted_media?(context.manager, context.project)
      refute Permissions.can_view_project_deleted_media?(context.editor, context.project)
    end

    test "can_edit_project_members?/2", context do
      assert Permissions.can_edit_project_members?(context.owner, context.project)
      refute Permissions.can_edit_project_members?(context.manager, context.project)
    end

    test "can_change_project_active_status?/2", context do
      assert Permissions.can_change_project_active_status?(context.owner, context.project)
      refute Permissions.can_change_project_active_status?(context.manager, context.project)
    end

    test "can_add_media_to_project?/2", context do
      assert Permissions.can_add_media_to_project?(context.editor, context.project)
      refute Permissions.can_add_media_to_project?(context.user, context.project)
    end

    test "can_delete_media?/2", context do
      assert Permissions.can_delete_media?(context.manager, context.media)
      refute Permissions.can_delete_media?(context.editor, context.media)
    end

    test "can_view_media?/2", context do
      assert Permissions.can_view_media?(context.owner, context.media)
      refute Permissions.can_view_media?(context.user, context.media)
    end

    test "can_edit_media?/2", context do
      assert Permissions.can_edit_media?(context.editor, context.media)
      refute Permissions.can_edit_media?(context.user, context.media)
    end

    test "can_comment_on_media?/2", context do
      assert Permissions.can_comment_on_media?(context.editor, context.media)
      refute Permissions.can_comment_on_media?(context.user, context.media)
    end

    test "can_merge_media?/2", context do
      assert Permissions.can_merge_media?(context.owner, context.media)
      refute Permissions.can_merge_media?(context.editor, context.media)
    end

    test "can_create_media?/1", context do
      assert Permissions.can_create_media?(context.editor)
    end
  end
end
