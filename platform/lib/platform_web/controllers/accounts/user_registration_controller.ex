defmodule PlatformWeb.UserRegistrationController do
  use PlatformWeb, :controller

  alias Platform.Accounts
  alias Platform.Accounts.User
  alias PlatformWeb.UserAuth
  alias Platform.Auditor

  def new(conn, params) do
    invite_code = Map.get(params, "invite_code", "")
    changeset = Accounts.change_user_registration(%User{invite_code: invite_code})
    render(conn, "new.html", changeset: changeset, title: "Register")
  end

  def create(conn, %{"user" => user_params} = params) do
    if Platform.Utils.check_captcha(params) do
      case Accounts.register_user(user_params) do
        {:ok, user} ->
          Auditor.log(:user_registered, %{email: user.email, username: user.username}, conn)

          {:ok, _} =
            Accounts.deliver_user_confirmation_instructions(
              user,
              &Routes.user_confirmation_url(conn, :edit, &1)
            )

          conn
          |> put_flash(:info, "User created successfully.")
          |> UserAuth.log_in_user(user)

        {:error, %Ecto.Changeset{} = changeset} ->
          render(conn, "new.html", changeset: changeset, title: "Register")
      end
    else
      render(conn, "new.html",
        changeset:
          Accounts.change_user_registration(%User{}, user_params)
          |> Ecto.Changeset.add_error(:captcha, "Invalid captcha!")
          |> Map.put(:action, :save),
        title: "Register"
      )
    end
  end
end
