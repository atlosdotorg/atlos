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
      Auditor.log(:login, %{username: user.username}, conn)
      UserAuth.log_in_user(conn, user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      _ ->
        render(conn, "new.html",
          error_message: "Invalid email, password, or captcha.",
          title: "Sign in"
        )
    end
  end

  def delete(conn, _params) do
    Auditor.log(:log_out, %{}, conn)

    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
