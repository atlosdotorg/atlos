defmodule Platform.NotificationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Platform.Notifications` context.
  """

  alias Platform.Accounts

  @doc """
  Generate a notification.
  """
  def notification_fixture(attrs \\ %{}) do
    {:ok, notification} =
      attrs
      |> Enum.into(%{
        content: "some content",
        read: false,
        type: :other,
        user_id: Accounts.get_auto_account().id
      })
      |> Platform.Notifications.create_notification()

    notification
  end
end
