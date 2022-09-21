defmodule Platform.NotificationsTest do
  use Platform.DataCase

  alias Platform.Notifications

  describe "notifications" do
    alias Platform.Notifications.Notification

    import Platform.NotificationsFixtures

    @invalid_attrs %{content: nil, read: nil, type: nil}

    test "list_notifications/0 returns all notifications" do
      notification = notification_fixture()
      assert Notifications.list_notifications() == [notification]
    end

    test "get_notification!/1 returns the notification with given id" do
      notification = notification_fixture()
      assert Notifications.get_notification!(notification.id).id == notification.id
    end

    test "create_notification/1 with valid data creates a notification" do
      valid_attrs = %{
        content: "some content",
        read: true,
        type: :update,
        user_id: Platform.Accounts.get_auto_account().id
      }

      assert {:ok, %Notification{} = notification} =
               Notifications.create_notification(valid_attrs)

      assert notification.content == "some content"
      assert notification.read == true
      assert notification.type == :update
    end

    test "create_notification/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Notifications.create_notification(@invalid_attrs)
    end

    test "update_notification/2 with valid data updates the notification" do
      notification = notification_fixture()
      update_attrs = %{content: "some updated content", read: false, type: :other}

      assert {:ok, %Notification{} = notification} =
               Notifications.update_notification(notification, update_attrs)

      assert notification.content == "some updated content"
      assert notification.read == false
      assert notification.type == :other
    end

    test "update_notification/2 with invalid data returns error changeset" do
      notification = notification_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Notifications.update_notification(notification, @invalid_attrs)
    end

    test "delete_notification/1 deletes the notification" do
      notification = notification_fixture()
      assert {:ok, %Notification{}} = Notifications.delete_notification(notification)
      assert_raise Ecto.NoResultsError, fn -> Notifications.get_notification!(notification.id) end
    end

    test "change_notification/1 returns a notification changeset" do
      notification = notification_fixture()
      assert %Ecto.Changeset{} = Notifications.change_notification(notification)
    end
  end
end
