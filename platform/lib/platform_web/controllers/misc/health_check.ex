defmodule PlatformWeb.HealthCheckController do
  use PlatformWeb, :controller

  def index(conn, _params) do
    resp = Platform.Repo.query("SELECT 1")

    case resp do
      {:ok, _} -> json(conn, %{status: "ok"})
      {:error, _} -> conn |> put_status(500) |> json(%{status: "error"})
    end
  end

  def app_running_longer_than_twelve_hours? do
    diff =
      (:erlang.monotonic_time() - :erlang.system_info(:start_time)) /
        :erlang.convert_time_unit(1, :second, :native)

    diff > 12 * 60 * 60
  end

  @doc """
  This endpoint will return a non-200 status code after the app has been running for more than 12 hours.
  We use this to tell Container Apps to restart the app. We do this to 1) avoid potential memory/disk usage leaks,
  and 2) to refresh our credentials (which generally expire after 24 hours).

  /health_check/exp is used by Container Apps to determine if the app should be restarted via a liveness probe.
  """
  def exp(conn, _params) do
    if app_running_longer_than_twelve_hours?() do
      conn |> put_status(400) |> json(%{status: "shutdown"})
    else
      conn |> put_status(200) |> json(%{status: "ok"})
    end
  end
end
