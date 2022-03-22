defmodule PlatformWeb.MountHelperLive do
  import Phoenix.LiveView
  alias Platform.Accounts

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket |> attach_path_hook()}
  end

  def on_mount(:authenticated, _params, %{"user_token" => user_token} = _session, socket) do
    socket = socket
      |> attach_path_hook()
      |> assign_new(:current_user, fn ->
        Accounts.get_user_by_session_token(user_token)
      end)

    unless is_nil(socket.assigns.current_user) do
      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/users/log_in")} # TODO: use routes
    end
  end

  defp attach_path_hook(socket) do
    attach_hook(socket, :set_active_path, :handle_params, fn
      _params, url, socket ->
        {:cont, assign(socket, path: URI.parse(url).path)}
      end
    )
  end
end
