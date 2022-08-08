defmodule PlatformWeb.UserResetPasswordController do
  use PlatformWeb, :controller

  alias Platform.Accounts
  alias Platform.Auditor

  plug :get_user_by_reset_password_token when action in [:edit, :update]

  def new(conn, _params) do
    render(conn, "new.html", title: "Reset password")
  end

  def create(conn, %{"user" => %{"email" => email}} = params) do
    with true <- Platform.Utils.check_captcha(params),
         user <- Accounts.get_user_by_email(email),
         false <- is_nil(user) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &Routes.user_reset_password_url(conn, :edit, &1)
      )
    end

    Auditor.log(:password_recovery_requested, %{email: email}, conn)

    conn
    |> put_flash(
      :info,
      "If your email is in our system, you will receive instructions to reset your password shortly."
    )
    |> redirect(to: "/users/log_in")
  end

  def edit(conn, _params) do
    render(conn, "edit.html",
      changeset: Accounts.change_user_password(conn.assigns.user),
      title: "Change password"
    )
  end

  # Do not log in the user after reset password to avoid a
  # leaked token giving the user access to the account.
  def update(conn, %{"user" => user_params}) do
    case Accounts.reset_user_password(conn.assigns.user, user_params) do
      {:ok, _} ->
        Auditor.log(:password_recovered, %{username: conn.assigns.user.username}, conn)

        conn
        |> put_flash(:info, "Password reset successfully.")
        |> redirect(to: Routes.user_session_path(conn, :new))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset, title: "Change password")
    end
  end

  defp get_user_by_reset_password_token(conn, _opts) do
    %{"token" => token} = conn.params

    if user = Accounts.get_user_by_reset_password_token(token) do
      conn |> assign(:user, user) |> assign(:token, token)
    else
      conn
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
