defmodule PlatformWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :platform

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    max_age: 24 * 60 * 60 * 30,
    key: "_platform_key",
    signing_salt: System.get_env("COOKIE_SIGNING_SALT", "change this in production")
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [
      connect_info: [:x_headers, :peer_data, session: @session_options],
      timeout: :infinity
    ]
  )

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug(Plug.Static,
    at: "/",
    from: :platform,
    gzip: false,
    only: ~w(assets ugc fonts images favicon.ico robots.txt)
  )

  plug(Plug.Static,
    at: "/artifacts",
    from: "artifacts"
  )

  plug(Plug.Static,
    at: "/avatars",
    from: "avatars"
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
    plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :platform)
  end

  plug(Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"
  )

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(PlatformWeb.Plugs.RemoteIp)
  plug(PlatformWeb.Router)
end
