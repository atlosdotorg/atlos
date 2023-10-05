defmodule Platform.ProjectsTest do
  use Platform.DataCase, async: true

  alias Platform.Projects

  describe "projects" do
    alias Platform.Projects.Project

    import Platform.ProjectsFixtures

    @invalid_attrs %{code: nil, name: nil}

    test "list_projects/0 returns all projects" do
      project = project_fixture()
      assert hd(Projects.list_projects()).name == project.name
      assert length(Projects.list_projects()) == 1
    end

    test "get_project!/1 returns the project with given id" do
      project = project_fixture()
      assert Projects.get_project!(project.id).name == project.name
    end

    test "create_project/1 with valid data creates a project" do
      valid_attrs = %{code: "code", name: "some name"}

      assert {:ok, %Project{} = project} = Projects.create_project(valid_attrs)
      assert project.code == "CODE"
      assert project.name == "some name"
    end

    test "create_project/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Projects.create_project(@invalid_attrs)
    end

    test "update_project/2 with valid data updates the project" do
      project = project_fixture()
      update_attrs = %{code: "code2", name: "some updated name"}

      assert {:ok, %Project{} = project} = Projects.update_project(project, update_attrs)
      assert project.code == "CODE2"
      assert project.name == "some updated name"
    end

    test "update_project/2 with invalid data returns error changeset" do
      project = project_fixture()
      assert {:error, %Ecto.Changeset{}} = Projects.update_project(project, @invalid_attrs)
      assert project.name == Projects.get_project!(project.id).name
    end

    test "delete_project/1 deletes the project" do
      project = project_fixture()
      assert {:ok, %Project{}} = Projects.delete_project(project)
      assert_raise Ecto.NoResultsError, fn -> Projects.get_project!(project.id) end
    end

    test "change_project/1 returns a project changeset" do
      project = project_fixture()
      assert %Ecto.Changeset{} = Projects.change_project(project)
    end
  end

  describe "project_memberships" do
    alias Platform.Projects.ProjectMembership

    import Platform.ProjectsFixtures

    @invalid_attrs %{role: nil}

    test "list_project_memberships/0 returns all project_memberships" do
      project_membership = project_membership_fixture()
      list = Projects.list_project_memberships()
      assert length(list) == 1
      assert are_memberships_equivalent?(hd(list), project_membership)
    end

    test "get_project_membership!/1 returns the project_membership with given id" do
      project_membership = project_membership_fixture()

      assert are_memberships_equivalent?(
               Projects.get_project_membership!(project_membership.id),
               project_membership
             )
    end

    test "create_project_membership/1 with valid data creates a project_membership" do
      valid_attrs = %{
        role: :owner,
        project_id: project_fixture().id,
        username: Platform.AccountsFixtures.user_fixture().username
      }

      assert {:ok, %ProjectMembership{} = project_membership} =
               Projects.create_project_membership(valid_attrs)

      assert project_membership.role == :owner
    end

    test "create_project_membership/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Projects.create_project_membership(@invalid_attrs)
    end

    test "update_project_membership/2 with valid data updates the project_membership" do
      project_membership = project_membership_fixture()
      update_attrs = %{role: :manager}

      assert {:ok, %ProjectMembership{} = project_membership} =
               Projects.update_project_membership(project_membership, update_attrs)

      assert project_membership.role == :manager
    end

    test "update_project_membership/2 with invalid data returns error changeset" do
      project_membership = project_membership_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Projects.update_project_membership(project_membership, @invalid_attrs)

      assert are_memberships_equivalent?(
               project_membership,
               Projects.get_project_membership!(project_membership.id)
             )
    end

    test "delete_project_membership/1 deletes the project_membership" do
      project_membership = project_membership_fixture()
      assert {:ok, %ProjectMembership{}} = Projects.delete_project_membership(project_membership)

      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_project_membership!(project_membership.id)
      end
    end

    test "change_project_membership/1 returns a project_membership changeset" do
      project_membership = project_membership_fixture()
      assert %Ecto.Changeset{} = Projects.change_project_membership(project_membership)
    end

    defp are_memberships_equivalent?(membership1, membership2) do
      membership1.role == membership2.role and
        membership1.project_id == membership2.project_id and
        membership1.user_id == membership2.user_id
    end
  end
end
