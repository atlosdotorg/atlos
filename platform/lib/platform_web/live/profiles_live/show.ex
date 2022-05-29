defmodule PlatformWeb.ProfilesLive.Show do
  use PlatformWeb, :live_view
  alias Platform.Accounts
  alias Platform.Updates
  alias PlatformWeb.ProfilesLive.EditComponent

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"username" => username} = _params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:username, username)
     |> assign(:title, username)
     |> assign_user()}
  end

  defp assign_user(socket) do
    with %Accounts.User{} = user <- Accounts.get_user_by_username(socket.assigns.username),
         false <-
           Accounts.is_suspended(user) && !Accounts.is_privileged(socket.assigns.current_user) do
      socket |> assign(:user, user) |> assign(:updates, Updates.get_updates_for_user(user))
    else
      _ ->
        socket
        |> put_flash(:error, "This user does not exist or is not available.")
        |> redirect(to: "/")
    end
  end
end
