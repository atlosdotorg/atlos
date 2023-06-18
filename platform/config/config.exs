# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :platform,
  ecto_repos: [Platform.Repo]

# Feature flags
config :platform, :features, custom_project_attributes: true, project_access_controls: true

# Configures the endpoint
config :platform, PlatformWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: PlatformWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Platform.PubSub,
  live_view: [signing_salt: "ZesKOiEA"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :platform, Platform.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, Swoosh.ApiClient.Hackney

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.0",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :remote_ip, :username]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Use Waffle for file uploads
cond do
  not is_nil(System.get_env("S3_BUCKET")) ->
    config :waffle, Waffle.Storage.S3,
      bucket: {:system, "S3_BUCKET"},
      virtual_host: true,
      # milliseconds
      version_timeout: 120_000

  # Perhaps we'll support other storage backends in the future...

  true ->
    config :waffle,
      storage: Waffle.Storage.Local,
      asset_host: "http://localhost:#{System.get_env("PORT", "4000")}/"
end

config :ex_aws,
  access_key_id: {:system, "AWS_ACCESS_KEY_ID"},
  secret_access_key: {:system, "AWS_SECRET_ACCESS_KEY"},
  region: {:system, "AWS_REGION"},
  s3: [
    region: {:system, "AWS_REGION"}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

import_config "appsignal.exs"

config :platform, Oban,
  repo: Platform.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"0 * * * *", Platform.Workers.Custodian}
     ]}
  ],
  # We only want one instance of ffmpeg running on the server at a time...
  queues: [media_archival: 1, auto_metadata: 1, custodian: 1, duplicate_detection: 3]
