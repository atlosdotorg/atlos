defmodule Platform.Mailer do
  use Swoosh.Mailer, otp_app: :platform
  import Swoosh.Email

  alias __MODULE__

  # Delivers the email using the application mailer.
  def construct_and_send(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(
        {"Atlos Notifications", System.get_env("MAILER_FROM_ADDRESS", "noreply@mail.atlos.org")}
      )
      |> subject(subject)
      |> text_body(body)

    Task.start(fn ->
      {:ok, _metadata} = Mailer.deliver(email)
    end)

    {:ok, email}
  end
end
