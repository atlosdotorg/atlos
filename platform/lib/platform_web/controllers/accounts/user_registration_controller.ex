defmodule PlatformWeb.UserRegistrationController do
  use PlatformWeb, :controller

  alias Platform.Accounts
  alias Platform.Accounts.User
  alias PlatformWeb.UserAuth
  alias Platform.Auditor

  def suspended(conn, _params) do
    if Map.get(conn.assigns, :current_user) != nil and
         !Accounts.is_suspended(Map.get(conn.assigns, :current_user)) do
      conn |> redirect(to: "/")
    else
      render(conn, "suspended.html", title: "Account Suspended")
    end
  end

  def no_access(conn, _params) do
    if Platform.Security.get_security_mode_state() != :no_access do
      conn |> redirect(to: "/")
    else
      render(conn, "no_access.html", title: "Maintenance Mode")
    end
  end

  def onboarding(conn, _params) do
    render(conn, "onboarding.html",
      title: "Welcome to Atlos",
      discord_link: System.get_env("COMMUNITY_DISCORD_LINK")
    )
  end

  def new(conn, params) do
    invite_code = Map.get(params, "invite_code", "")
    invite = Platform.Invites.get_invite_by_code(invite_code)
    changeset = Accounts.change_user_registration(%User{invite_code: invite_code})
    render(conn, "new.html", changeset: changeset, title: "Register", invite: invite)
  end

  def create(conn, %{"user" => user_params} = params) do
    if Platform.Utils.check_captcha(params) do
      case Accounts.register_user(user_params) do
        {:ok, user} ->
          Auditor.log(:user_registered, %{email: user.email, username: user.username}, conn)

          Task.start(fn ->
            Accounts.deliver_user_confirmation_instructions(
              user,
              &Routes.user_confirmation_url(conn, :edit, &1)
            )

            Platform.Projects.create_onboarding_project_for_user(user)
          end)

          conn
          |> put_flash(:info, "Account created successfully.")
          |> put_session(:user_return_to, Routes.user_registration_path(conn, :onboarding))
          |> UserAuth.log_in_user(user)

        {:error, %Ecto.Changeset{} = changeset} ->
          invite_code = Map.get(params, "invite_code", "")
          invite = Platform.Invites.get_invite_by_code(invite_code)
          render(conn, "new.html", changeset: changeset, title: "Register", invite: invite)
      end
    else
      invite_code = Map.get(params, "invite_code", "")
      invite = Platform.Invites.get_invite_by_code(invite_code)

      render(conn, "new.html",
        changeset:
          Accounts.change_user_registration(%User{}, user_params)
          |> Ecto.Changeset.add_error(:captcha, "Invalid captcha. Please try again.")
          |> Map.put(:action, :save),
        title: "Register",
        invite: invite
      )
    end
  end
end
