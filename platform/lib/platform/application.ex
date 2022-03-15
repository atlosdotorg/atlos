defmodule Platform.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Platform.Repo,
      # Start the Telemetry supervisor
      PlatformWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Platform.PubSub},
      # Start the Endpoint (http/https)
      PlatformWeb.Endpoint
      # Start a worker by calling: Platform.Worker.start_link(arg)
      # {Platform.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Platform.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PlatformWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
