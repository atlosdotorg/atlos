defmodule PlatformWeb.InviteController do
  alias Platform.Projects
  alias Platform.Projects.Project
  use PlatformWeb, :controller

  alias Platform.Accounts
  alias Platform.Invites
  alias Platform.Auditor

  def new(conn, %{"code" => code}) do
    invite = Invites.get_invite_by_code(code)

    if Invites.is_invite_active(invite) and is_nil(conn.assigns.current_user) do
      # Redirect them to the sign up page with the invite code in the params
      conn
      |> redirect(to: Routes.user_registration_path(conn, :new, %{"invite_code" => code}))
    else
      is_member_already =
        not is_nil(invite) and not is_nil(invite.project) and
          Enum.member?(
            Projects.get_project_users(invite.project) |> Enum.map(& &1.id),
            conn.assigns.current_user.id
          )

      title =
        case invite do
          nil ->
            "Invalid invite code"

          %Invites.Invite{project: nil} ->
            "#{invite.owner.username} has invited you to Atlos"

          %Invites.Invite{project: project} ->
            "#{invite.owner.username} has invited you to #{project.name}"
        end

      render(conn, "new.html", title: title, invite: invite, is_member_already: is_member_already)
    end
  end

  def accept(conn, %{"code" => code}) do
    if is_nil(conn.assigns.current_user) do
      raise PlatformWeb.Errors.Unauthorized, "You must be logged in to use an invite code"
    end

    invite = Invites.get_invite_by_code(code)

    # Apply the invite code to the user
    {:ok, _} =
      Platform.Repo.transaction(fn ->
        {:ok, _} = Invites.apply_invite_code(conn.assigns.current_user, code)
      end)

    conn
    |> put_flash(
      :info,
      "You have accepted the invite from #{invite.owner.username}"
    )
    |> redirect(to: if(is_nil(invite.project), do: "/", else: "/projects/#{invite.project.id}"))
  end

  def redirect_to_sign_in(conn, %{"code" => code}) do
    conn
    |> put_session(:user_return_to, Routes.invite_path(conn, :new, code))
    |> redirect(to: Routes.user_session_path(conn, :new))
  end
end
