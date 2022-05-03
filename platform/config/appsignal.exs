use Mix.Config

config :appsignal, :config,
  otp_app: :platform,
  name: "platform",
  push_api_key: System.get_env("APPSIGNAL_PUSH_KEY"),
  env: Mix.env()
