defmodule Platform.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Platform.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer() |> abs()}@example.com"
  def unique_user_username, do: "user#{System.unique_integer() |> abs()}"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      username: unique_user_username(),
      invite_code: Platform.Accounts.get_valid_invite_code()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Platform.Accounts.register_user()

    user
  end

  def admin_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Platform.Accounts.register_user()

    {:ok, admin} = Platform.Accounts.update_user_admin(user, %{roles: [:admin]})

    admin
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
