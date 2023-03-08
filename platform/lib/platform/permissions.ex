defmodule Platform.Permissions do
  @moduledoc """
  This module contains functions for checking permissions. This is intended as a central hub for all permission checks, so that we can easily change the logic in one place.
  """

  alias Platform.Accounts
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

  def can_view_media?(%User{} = user, %Media{} = media) do
    if is_nil(media.project) do
      true
    else
      membership = Projects.get_project_membership_by_user_and_project(user, media.project)

      case can_view_project?(user, media.project) do
        true ->
          case {media.attr_restrictions, media.deleted} do
            {nil, false} ->
              true

            {_, true} ->
              membership.role == :owner

            {values, false} ->
              # Restrictions are present.
              if Enum.member?(values, "Hidden") do
                membership.role == :owner or membership.role == :manager
              else
                true
              end
          end

        false ->
          # The user can't view the project, so they can't view the media.
          false
      end
    end
  end

  def can_edit_media?(%User{} = user, %Media{} = media) do
    # This includes uploading new media versions as well as editing attributes.

    membership = Projects.get_project_membership_by_user_and_project_id(user, media.project_id)

    # This logic would be nice to refactor into a `with` statement
    case Platform.Security.get_security_mode_state() do
      :normal ->
        case Enum.member?(user.restrictions || [], :muted) do
          true ->
            false

          false ->
            cond do
              is_nil(media.slug) ->
                # This is a new media object that hasn't been saved yet.
                true

              is_nil(media.project) ->
                # This media object is not associated with a project.
                true

              is_nil(membership) ->
                false

              membership.role == :owner ->
                true

              membership.role == :manager ->
                true

              membership.role == :editor ->
                not (Enum.member?(media.attr_restrictions || [], "Frozen") ||
                       media.attr_status == "Completed" || media.attr_status == "Cancelled")

              true ->
                false
            end
        end

      _ ->
        Accounts.is_admin(user)
    end
  end

  def can_edit_media?(%User{} = user, %Media{} = media, %Attribute{} = attribute) do
    # This includes uploading new media versions as well as editing attributes.
    membership = Projects.get_project_membership_by_user_and_project(user, media.project)

    with false <- is_nil(membership) and not is_nil(media.project),
         true <- can_edit_media?(user, media) do
      if attribute.is_restricted do
        membership.role == :owner or membership.role == :manager
      else
        true
      end
    else
      _ -> false
    end
  end

  def can_comment_on_media?(%User{} = user, %Media{} = media) do
    # This logic would be nice to refactor into a `with` statement
    case Platform.Security.get_security_mode_state() do
      :normal ->
        case Enum.member?(user.restrictions || [], :muted) do
          true ->
            false

          false ->
            case media.attr_restrictions do
              nil ->
                can_view_media?(user, media)

              values ->
                # Restrictions are present.
                if not is_nil(media.project) and
                     (Enum.member?(values, "Hidden") || Enum.member?(values, "Frozen")) do
                  membership =
                    Projects.get_project_membership_by_user_and_project(user, media.project)

                  membership.role == :owner or membership.role == :manager
                else
                  true
                end
            end
        end

      _ ->
        Accounts.is_admin(user)
    end
  end

  def can_create_media?(%User{} = user) do
    # Separate from `can_add_media_to_project?` because this is for creating media that is not yet associated with a project.
    not Enum.member?(user.restrictions || [], :muted)
  end
end
