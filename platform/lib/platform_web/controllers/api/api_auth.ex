defmodule PlatformWeb.APIAuth do
  import Plug.Conn
  use PlatformWeb, :controller

  alias Platform.API

  def check_api_token(conn, _opts) do
    with ["Bearer " <> provided] <- get_req_header(conn, "authorization"),
         token when not is_nil(token) <- API.get_api_token_by_value(provided) do
      conn |> assign(:token, token)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid token or token not found"})
        |> halt()
    end
  end
end
