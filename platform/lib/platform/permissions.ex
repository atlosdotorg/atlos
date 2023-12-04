defmodule Platform.Permissions do
  @moduledoc """
  This module contains functions for checking permissions. This is intended as a central hub for all permission checks, so that we can easily change the logic in one place.
  """

  use Memoize

  alias Platform.Material
  alias Platform.Accounts
  alias Platform.Accounts.User
  alias Platform.Material.Media
  alias Platform.Material.MediaVersion
  alias Platform.Material.Attribute
  alias Platform.Updates.Update
  alias Platform.Projects
  alias Platform.Projects.Project
  alias Platform.API.APIToken

  def can_view_project?(%User{} = user, %Project{} = project) do
    not is_nil(Projects.get_project_membership_by_user_and_project(user, project))
  end

  def can_create_project?(%User{} = user) do
    case Platform.Security.get_security_mode_state() do
      :normal ->
        # Everyone can create a project
        case System.get_env("RESTRICT_PROJECT_CREATION") do
          "true" -> Accounts.is_privileged(user)
          _ -> not Accounts.is_muted(user)
        end

      _ ->
        Accounts.is_admin(user)
    end
  end

  def can_edit_project_metadata?(%User{} = user, %Project{id: nil}) do
    can_create_project?(user)
  end

  def can_edit_project_metadata?(%User{} = _, %Project{active: false}) do
    false
  end

  def can_edit_project_metadata?(%User{} = user, %Project{} = project) do
    case Projects.get_project_membership_by_user_and_project(user, project) do
      %Projects.ProjectMembership{role: :owner} -> true
      %Projects.ProjectMembership{role: :manager} -> true
      _ -> false
    end
  end

  def can_view_project_deleted_media?(%User{} = user, %Project{} = project) do
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

  def can_edit_project_api_tokens?(%User{} = user, %Project{} = project) do
    case Projects.get_project_membership_by_user_and_project(user, project) do
      %Projects.ProjectMembership{role: :owner} -> true
      _ -> false
    end
  end

  defmemo _is_media_editable?(%Media{project_id: nil} = media), expires_in: 5000 do
    true
  end

  defmemo _is_media_editable?(%Media{} = media), expires_in: 5000 do
    # Security mode must be normal, the media can't be deleted, and its project must be active.

    with :normal <- Platform.Security.get_security_mode_state(),
         false <- media.deleted,
         true <- Projects.get_project(media.project_id).active do
      true
    else
      _ -> false
    end
  end

  def can_api_token_post_comment?(%APIToken{} = token, %Media{} = media) do
    Enum.member?(token.permissions, :comment) and token.is_active and
      token.project_id == media.project_id and _is_media_editable?(media)
  end

  def can_api_token_edit_media?(%APIToken{} = token, %Media{} = media) do
    Enum.member?(token.permissions, :edit) and token.is_active and
      token.project_id == media.project_id and _is_media_editable?(media)
  end

  def can_api_token_update_attribute?(
        %APIToken{} = token,
        %Media{} = media,
        %Attribute{} = _attribute
      ) do
    can_api_token_edit_media?(token, media)
  end

  def can_change_project_active_status?(%User{} = user, %Project{} = project) do
    case Projects.get_project_membership_by_user_and_project(user, project) do
      %Projects.ProjectMembership{role: :owner} -> true
      _ -> false
    end
  end

  def can_add_media_to_project?(%User{} = user, %Project{active: false} = project) do
    false
  end

  def can_add_media_to_project?(%User{} = user, %Project{} = project) do
    case Projects.get_project_membership_by_user_and_project(user, project) do
      %Projects.ProjectMembership{role: :owner} -> true
      %Projects.ProjectMembership{role: :manager} -> true
      %Projects.ProjectMembership{role: :editor} -> true
      _ -> false
    end
  end

  def can_bulk_upload_media_to_project?(%User{} = user, %Project{active: false} = project) do
    false
  end

  def can_bulk_upload_media_to_project?(%User{} = user, %Project{} = project) do
    case Projects.get_project_membership_by_user_and_project(user, project) do
      %Projects.ProjectMembership{role: :owner} -> true
      %Projects.ProjectMembership{role: :manager} -> true
      _ -> false
    end
  end

  def can_delete_media?(%User{} = user, %Media{} = media) do
    # This is a soft delete
    Projects.get_project(media.project_id).active and
      case Projects.get_project_membership_by_user_and_project_id(user, media.project_id) do
        %Projects.ProjectMembership{role: :owner} -> true
        %Projects.ProjectMembership{role: :manager} -> true
        _ -> false
      end
  end

  def can_view_media?(%User{} = user, %Media{project_id: nil} = media) do
    true
  end

  def can_view_media?(%User{} = user, %Media{} = media) do
    membership = Projects.get_project_membership_by_user_and_project_id(user, media.project_id)
    project = Projects.get_project(media.project_id)

    if is_nil(membership) do
      false
    else
      case can_view_project?(user, project) do
        true ->
          case {media.attr_restrictions, media.deleted} do
            {nil, false} ->
              true

            {_, true} ->
              membership.role == :owner or membership.role == :manager

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

    with true <- _is_media_editable?(media),
         true <- can_view_media?(user, media),
         true <- not is_nil(membership) or is_nil(media.project_id),
         false <- Enum.member?(user.restrictions || [], :muted),
         true <-
           is_nil(media.slug) or is_nil(media.project) or
             membership.role == :owner or membership.role == :manager or
             (membership.role == :editor and
                not (Enum.member?(media.attr_restrictions || [], "Frozen") ||
                       media.attr_status == "Completed" || media.attr_status == "Cancelled")) do
      true
    else
      _ -> false
    end
  end

  def can_edit_media?(%User{} = user, %Media{} = media, %Attribute{} = attribute) do
    # This includes uploading new media versions as well as editing attributes.
    membership = Projects.get_project_membership_by_user_and_project_id(user, media.project_id)

    with false <- is_nil(membership),
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

  def can_set_restricted_attribute_values?(
        %User{} = user,
        %Media{} = media,
        %Attribute{} = _attribute
      ) do
    membership = Projects.get_project_membership_by_user_and_project_id(user, media.project_id)

    with false <- is_nil(membership),
         true <- can_edit_media?(user, media) do
      membership.role == :owner or membership.role == :manager
    else
      _ -> false
    end
  end

  def can_comment_on_media?(%User{} = user, %Media{} = media) do
    if Accounts.is_auto_account(user) do
      true
    else
      membership = Projects.get_project_membership_by_user_and_project_id(user, media.project_id)

      with true <- _is_media_editable?(media),
           true <- can_view_media?(user, media),
           true <-
             is_nil(media.attr_restrictions) or
               (not is_nil(media.project) and
                  (Enum.member?(media.attr_restrictions, "Hidden") or
                     Enum.member?(media.attr_restrictions, "Frozen")) and
                  (membership.role == :owner or membership.role == :manager)) do
        true
      else
        _ -> false
      end
    end
  end

  def can_merge_media?(%User{} = user, %Media{} = media) do
    membership = Projects.get_project_membership_by_user_and_project_id(user, media.project_id)

    with false <- is_nil(membership),
         true <- can_edit_media?(user, media) do
      membership.role == :owner or membership.role == :manager
    else
      _ -> false
    end
  end

  def can_copy_media?(%User{} = user, %Media{} = media) do
    membership = Projects.get_project_membership_by_user_and_project_id(user, media.project_id)

    with false <- is_nil(membership),
         true <- can_edit_media?(user, media) do
      membership.role == :owner or membership.role == :manager
    else
      _ -> false
    end
  end

  def can_create_media?(%User{} = user) do
    # Separate from `can_add_media_to_project?` because this is for creating media that is not yet associated with a project.
    not Enum.member?(user.restrictions || [], :muted)
  end

  defmemo _get_media_from_id(media_id), expires_in: 1000 do
    # Memoized media lookup to avoid hitting the database multiple times for the same media during a request.
    # This is a classic n+1 query problem; we should probably fix it at the database level.
    Material.get_media!(media_id)
  end

  def can_view_update?(%User{} = user, %Update{} = update) do
    media = _get_media_from_id(update.media_id)

    with true <- can_view_media?(user, media) do
      membership = Projects.get_project_membership_by_user_and_project(user, media.project)

      case update.hidden do
        true -> membership.role == :owner or membership.role == :manager
        false -> true
      end
    else
      _ -> false
    end
  end

  def can_view_media_version?(%User{} = user, %MediaVersion{} = version) do
    media = _get_media_from_id(version.media_id)

    with true <- can_view_media?(user, media) do
      membership = Projects.get_project_membership_by_user_and_project(user, media.project)

      case version.visibility == :removed do
        true -> membership.role == :owner or membership.role == :manager
        false -> true
      end
    else
      _ -> false
    end
  end

  def can_change_media_version_visibility?(%User{} = user, %MediaVersion{} = version) do
    media = _get_media_from_id(version.media_id)

    with true <- can_view_media?(user, media) do
      membership = Projects.get_project_membership_by_user_and_project(user, media.project)

      membership.role == :owner or membership.role == :manager
    else
      _ -> false
    end
  end

  def can_rearchive_media_version?(%User{} = user, %MediaVersion{} = version) do
    # They can view it, and its status is :error
    can_view_media_version?(user, version) and version.status == :error and
      version.upload_type == :direct
  end

  def can_user_change_update_visibility?(%User{} = user, %Update{} = update) do
    media = _get_media_from_id(update.media_id)

    with true <- can_view_media?(user, media) do
      membership = Projects.get_project_membership_by_user_and_project(user, media.project)

      membership.role == :owner or membership.role == :manager
    else
      _ -> false
    end
  end

  def can_export_full?(%User{} = user, %Project{} = project) do
    case Projects.get_project_membership_by_user_and_project(user, project) do
      %Projects.ProjectMembership{role: :owner} -> true
      %Projects.ProjectMembership{role: :manager} -> true
      _ -> false
    end
  end
end
