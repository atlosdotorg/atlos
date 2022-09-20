defmodule Platform.Auditor do
  @moduledoc """
  This module implements important auditing behavior for the platform.
  """

  require Logger

  def log(event, metadata, socket_or_conn \\ %{}) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    assigns = Map.get(socket_or_conn, :assigns, %{})

    user = Map.get(assigns, :current_user) || %{}
    username = user |> Map.get(:username)

    # This is set by our `PlatformWeb.Plugs.RemoteIp` middleware
    ip = Map.get(assigns, :remote_ip)

    complete_metadata = Map.merge(metadata, %{authed_username: username, remote_ip: ip})

    {pretty_metadata_json, raw_metadata_json} =
      try do
        {:ok, val} = Jason.encode(complete_metadata)
        printed = Jason.Formatter.pretty_print(val)
        {printed |> String.replace("```", "'''"), val}
      rescue
        _ ->
          {"{}", "{}"}
      end

    Logger.notice("[auditor] #{event} #{raw_metadata_json}")

    slack_webhook = System.get_env("SLACK_AUDITING_WEBHOOK")
    environment = System.get_env("ENVIRONMENT", "dev")

    if not is_nil(slack_webhook) and environment != "dev" do
      Task.start(fn ->
        :hackney.post(
          slack_webhook,
          [{"content-type", "application/json"}],
          Jason.encode!(%{
            text: "#{event} (user: #{username || "not logged in"}, environment: #{environment})",
            blocks: [
              %{
                type: "divider"
              },
              %{
                type: "section",
                text: %{
                  type: "mrkdwn",
                  text: "> `#{event}` by #{username || "[not logged in]"}"
                }
              },
              %{
                type: "section",
                text: %{
                  type: "mrkdwn",
                  text: "```#{pretty_metadata_json}```"
                }
              },
              %{
                type: "context",
                elements: [
                  %{
                    type: "mrkdwn",
                    text: "#{now} @ #{environment}"
                  }
                ]
              }
            ]
          }),
          [:with_body]
        )
      end)
    end
  end
end
