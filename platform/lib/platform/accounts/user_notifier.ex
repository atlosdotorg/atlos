defmodule Platform.Accounts.UserNotifier do
  alias Platform.Accounts.User
  alias Platform.Material.Media
  alias Platform.Updates.Update
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
  Deliver a notification that the user has been tagged.
  """
  def deliver_tag_notification(%User{} = user, %User{} = tagger, %Media{} = media, %Update{} = update, url) do
    Mailer.construct_and_send(user.email, "#", """
    Hi #{user.username},

    #{tagger.username} tagged you on #{Media.slug_to_display(media)}:

    #{update.explanation |> Platform.Utils.render_markdown() |> Platform.Utils.strip_html_tags()}

    View the comment here: #{url}

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
  def deliver_login_notification(user, ip_address, change_password_url) do
    Mailer.construct_and_send(user.email, "New login to your account", """
    Hi #{user.username},

    Someone just logged into your Atlos account#{if is_bitstring(ip_address), do: " from the IP address " <> ip_address, else: ""}.

    If this was you, great! If not, please change your Atlos password immediately and notify us at contact@atlos.org. (Changing your password will log everyone out of your account.)

    If necessary, you can change your password here: #{change_password_url}

    We know this email might feel excessive. But we take security extremely seriously at Atlos, and want to make sure that unauthorized logins are detected and remedied quickly.

    Best,
    The Atlos Team
    """)
  end
end
