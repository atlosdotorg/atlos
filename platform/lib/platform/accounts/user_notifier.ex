defmodule Platform.Accounts.UserNotifier do
  alias Platform.Mailer

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    Mailer.construct_and_send(user.email, "Confirmation instructions", """
    Hi #{user.email},

    Thanks for joining the Atlos researcher community!

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this message.

    Best,
    The Atlos Team
    """)
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    Mailer.construct_and_send(user.email, "Reset password instructions", """
    Hi #{user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this message.
    """)
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    Mailer.construct_and_send(user.email, "Update email instructions", """
    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this message.
    """)
  end
end
