import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# Start the phoenix server if environment is set and running in a release
if System.get_env("PHX_SERVER") && System.get_env("RELEASE_NAME") do
  config :platform, PlatformWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url =
    cond do
      not is_nil(System.get_env("DATABASE_URL")) ->
        System.get_env("DATABASE_URL")

      not is_nil(System.get_env("AZURE_POSTGRESQL_HOST")) ->
        "postgres://#{System.get_env("AZURE_POSTGRESQL_USERNAME")}:#{System.get_env("AZURE_POSTGRESQL_PASSWORD")}@#{System.get_env("AZURE_POSTGRESQL_HOST")}:#{System.get_env("AZURE_POSTGRESQL_PORT")}/#{System.get_env("AZURE_POSTGRESQL_DATABASE")}"

      true ->
        raise """
        environment variable DATABASE_URL is missing.
        For example: ecto://USER:PASS@HOST/DATABASE
        """
    end

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  config :platform, Platform.Repo,
    ssl: System.get_env("AZURE_POSTGRESQL_SSL", "false") == "true",
    # Azure does not provide a CA certificate that we can verify against; we have to hope that Azure is not MITM'ing us here.
    ssl_opts: [verify: :verify_none],
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20"),
    socket_options: maybe_ipv6,
    types: Platform.Repo.PostgresTypes

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :platform, PlatformWeb.Endpoint,
    url: [host: host, port: 443],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :platform, PlatformWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :platform, Platform.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
  config :platform, Platform.Mailer,
    adapter: Swoosh.Adapters.AmazonSES,
    region: System.get_env("AWS_MAILER_REGION", "us-east-1"),
    access_key: System.get_env("AWS_ACCESS_KEY_ID"),
    secret: System.get_env("AWS_SECRET_ACCESS_KEY")

  config :waffle,
    storage: Waffle.Storage.S3,
    bucket: {:system, "S3_BUCKET"},
    virtual_host: true,
    # milliseconds
    version_timeout: 120_000

  # Configure libcluster clustering
  cond do
    not is_nil(System.get_env("FLY_APP_NAME")) ->
      # We're running on fly.io
      app_name = System.get_env("FLY_APP_NAME")

      config :libcluster,
        # Always have debug logging
        debug: true,
        topologies: [
          fly6pn: [
            strategy: Cluster.Strategy.DNSPoll,
            config: [
              polling_interval: 5_000,
              query: "#{app_name}.internal",
              node_basename: app_name
            ]
          ]
        ]

    not System.get_env("SINGLE_NODE", "false") == "true" ->
      config :libcluster,
        # Always have debug logging
        debug: true,
        topologies: [
          dnspoll: [
            strategy: Cluster.Strategy.DNSPoll,
            config: [
              polling_interval: 5_000,
              query: "#{System.get_env("CONTAINER_APP_REVISION")}-headless",
              node_basename: "platform"
            ]
          ],
          k8s_dns: [
            strategy: Cluster.Strategy.Kubernetes.DNS,
            config: [
              polling_interval: 5_000,
              application_name: "platform",
              service: "#{System.get_env("CONTAINER_APP_REVISION")}-headless"
            ]
          ]
        ]
    true ->
      true
  end
end
