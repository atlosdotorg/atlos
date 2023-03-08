defmodule Platform.Permissions do
  @moduledoc """
  This module contains functions for checking permissions. This is intended as a central hub for all permission checks, so that we can easily change the logic in one place.
  """

  alias Platform.Accounts.User
  alias Platform.Material.Media
  alias Platform.Material.MediaVersion
  alias Platform.Material.Attribute
  alias Platform.Projects
  alias Platform.Projects.Project

  def can_view_project?(%User{} = user, %Project{} = project) do
    not is_nil(Projects.get_project_membership_by_user_and_project(user, project))
  end

  def can_create_project?(%User{} = _user) do
    # Everyone can create a project
    true
  end

  def can_edit_project_metadata?(%User{} = user, %Project{id: nil}) do
    can_create_project?(user)
  end

  def can_edit_project_metadata?(%User{} = user, %Project{} = project) do
    case Projects.get_project_membership_by_user_and_project(user, project) do
      %Projects.ProjectMembership{role: :owner} -> true
      %Projects.ProjectMembership{role: :manager} -> true
      _ -> false
    end
  end

  def can_edit_project_members?(%User{} = user, %Project{} = project) do
    case Projects.get_project_membership_by_user_and_project(user, project) do
      %Projects.ProjectMembership{role: :owner} -> true
      _ -> false
    end
  end

  def can_delete_project?(%User{} = user, %Project{} = project) do
    case Projects.get_project_membership_by_user_and_project(user, project) do
      %Projects.ProjectMembership{role: :owner} -> true
      _ -> false
    end
  end

  def can_add_media_to_project?(%User{} = user, %Project{} = project) do
    case Projects.get_project_membership_by_user_and_project(user, project) do
      %Projects.ProjectMembership{role: :owner} -> true
      %Projects.ProjectMembership{role: :manager} -> true
      %Projects.ProjectMembership{role: :editor} -> true
      _ -> false
    end
  end
end
