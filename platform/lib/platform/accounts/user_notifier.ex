defmodule Platform.Accounts.UserNotifier do
  alias Platform.Mailer

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    Mailer.construct_and_send(user.email, "Confirmation instructions", """
    Hi #{user.username},

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
    Hi #{user.username},

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
    Hi #{user.username},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this message.
    """)
  end

  @doc """
  Deliver notification of a new login.
  """
  def deliver_login_notification(user, ip_address) do
    Mailer.construct_and_send(user.email, "New login to your account", """
    Hi #{user.username},

    Someone just logged into your account from the IP address #{to_string(:inet_parse.ntoa(ip_address))}.

    If this was you, great! If not, please change your Atlos password immediately and notify us at contact@atlos.org.

    We know this email might feel excessive. But we take security extremely security at Atlos, and want to make sure that unauthorized logins are detected and remedied quickly.

    Best,
    The Atlos Team
    """)
  end
end
