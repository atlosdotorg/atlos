defmodule PlatformWeb.UserAuthLive do
  import Phoenix.LiveView
  alias Platform.Accounts

  def on_mount(_, _params, %{"user_token" => user_token} = _session, socket) do
    socket =
      assign_new(socket, :current_user, fn ->
        Accounts.get_user_by_session_token(user_token)
      end)

    unless is_nil(socket.assigns.current_user) do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/users/log_in")} # TODO: use routes
    end
  end
end
