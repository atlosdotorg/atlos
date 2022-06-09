defmodule PlatformWeb.MountHelperLive do
  import Phoenix.LiveView
  alias Platform.Accounts

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket |> attach_path_hook() |> attach_metadata()}
  end

  def on_mount(:authenticated, _params, %{"user_token" => user_token} = _session, socket) do
    socket =
      socket
      |> attach_path_hook()
      |> attach_metadata()
      |> assign_new(:current_user, fn ->
        Accounts.get_user_by_session_token(user_token)
      end)

    unless is_nil(socket.assigns.current_user) do
      {:cont, socket}
    else
      # TODO: use routes
      {:halt, redirect(socket, to: "/users/log_in")}
    end
  end

  def on_mount(:admin, params, session, socket) do
    with {:cont, new_socket} <- on_mount(:authenticated, params, session, socket) do
      if Accounts.is_admin(new_socket.assigns.current_user) do
        {:cont, new_socket}
      else
        {:halt,
         redirect(socket, to: "/")
         |> put_flash(:error, "You do not have permission to access this page.")}
      end
    else
      other -> other
    end
  end

  defp attach_path_hook(socket) do
    attach_hook(socket, :set_active_path, :handle_params, fn
      _params, url, socket ->
        {:cont, assign(socket, path: URI.parse(url).path)}
    end)
  end

  defp attach_metadata(socket) do
    headers = get_connect_info(socket, :x_headers)
    remote_ip = RemoteIp.from(headers)
    socket |> assign(:remote_ip, remote_ip)
  end
end
