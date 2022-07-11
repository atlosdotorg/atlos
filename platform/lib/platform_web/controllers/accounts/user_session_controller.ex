defmodule PlatformWeb.UserSessionController do
  use PlatformWeb, :controller

  alias Platform.Accounts
  alias PlatformWeb.UserAuth
  alias Platform.Auditor
  alias Platform.Utils

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil, title: "Sign in")
  end

  def create(conn, %{"user" => user_params} = params) do
    %{"email" => email, "password" => password} = user_params

    with true <- Utils.check_captcha(params),
         user <- Accounts.get_user_by_email_and_password(email, password),
         false <- is_nil(user) do
      if user.has_mfa do
        conn
        |> put_session(:prelim_authed_username, user.username)
        |> redirect(to: Routes.user_session_path(conn, :new_mfa))
      else
        UserAuth.log_in_user(conn, user)
      end
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      _ ->
        render(conn, "new.html",
          error_message: "Invalid email, password, or captcha.",
          title: "Sign in"
        )
    end
  end

  def new_mfa(conn, _params) do
    with user = %Accounts.User{} <-
           Accounts.get_user_by_username(get_session(conn, :prelim_authed_username)) do
      changeset = Accounts.confirm_user_mfa(user)
      render(conn, "mfa.html", title: "Multi-Factor Authentication", changeset: changeset)
    else
      _ -> redirect(conn, to: Routes.user_session_path(conn, :new))
    end
  end

  def create_mfa(conn, %{"mfa" => mfa_params} = _params) do
    with user = %Accounts.User{} <-
           Accounts.get_user_by_username(get_session(conn, :prelim_authed_username)) do
      changeset = Accounts.confirm_user_mfa(user, mfa_params) |> Map.put(:action, :validate)

      if changeset.valid? do
        UserAuth.log_in_user(conn, user)
      else
        render(conn, "mfa.html", title: "Multi-Factor Authentication", changeset: changeset)
      end
    else
      _ -> redirect(conn, to: Routes.user_session_path(conn, :new))
    end
  end

  def delete(conn, _params) do
    Auditor.log(:log_out, %{}, conn)

    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
