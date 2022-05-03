defmodule Platform.Auditor do
  @moduledoc """
  This module implements important auditing behavior for the platform.
  """

  require Logger

  def log(event, metadata, socket_or_conn \\ nil) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    user =
      (Map.get(socket_or_conn, :assigns) || %{})
      |> Map.get(:current_user) || %{}

    username = user |> Map.get(:username)

    ip = Map.get(socket_or_conn, :assigns, %{}) |> Map.get(:remote_ip, nil)

    complete_metadata = Map.merge(metadata, %{authed_username: username, remote_ip: ip})

    Logger.notice("#{event}", complete_metadata)

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
                  text:
                    "```#{Jason.encode!(complete_metadata) |> Jason.Formatter.pretty_print() |> String.replace("```", "'''")}```"
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
