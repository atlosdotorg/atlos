import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :platform, Platform.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "platform_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  types: Platform.Repo.PostgresTypes

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :platform, PlatformWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "wCtlJDRdK1Mavb6QCIjxx0yX2qSVW1R6PctHeLgQjBKqQT6rW3UbaoRjl2Vzkt1C",
  server: false

# In test we don't send emails.
config :platform, Platform.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Prevent tasks from being run at test-time
config :platform, Oban, testing: :inline

# Disable billing
System.put_env("BILLING_ENABLED", "false")

# Set the "MIX_ENV" environment variable to "test"
System.put_env("MIX_ENV", "test")
