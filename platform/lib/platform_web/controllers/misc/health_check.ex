defmodule PlatformWeb.HealthCheckController do
  use PlatformWeb, :controller

  def index(conn, _params) do
    resp = Platform.Repo.query("SELECT 1")

    case resp do
      {:ok, _} -> json(conn, %{status: "ok"})
      {:error, _} -> conn |> put_status(500) |> json(%{status: "error"})
    end
  end
end
