defmodule Platform.NotificationsTest do
  use Platform.DataCase, async: true

  alias Platform.Notifications

  describe "notifications" do
    alias Platform.Notifications.Notification

    import Platform.NotificationsFixtures

    @invalid_attrs %{content: nil, read: nil, type: nil}

    test "list_notifications/0 returns all notifications" do
      _ = notification_fixture()
      assert length(Notifications.list_notifications()) == 1
    end

    test "get_notification!/1 returns the notification with given id" do
      notification = notification_fixture()
      assert Notifications.get_notification!(notification.id).id == notification.id
    end

    test "get_notifications_by_user_paginated/2 returns the right notifications" do
      assert Notifications.get_notifications_by_user_paginated(
               Platform.Accounts.get_auto_account()
             ).entries == []

      %Notification{id: id1} = notification_fixture()

      # Sleep to ensure that the timestamps are different
      Process.sleep(2000)

      assert [
               %Notification{id: ^id1}
             ] =
               Notifications.get_notifications_by_user_paginated(
                 Platform.Accounts.get_auto_account()
               ).entries

      %Notification{id: id2} = notification_fixture()

      assert [
               %Notification{id: ^id2},
               %Notification{id: ^id1}
             ] =
               Notifications.get_notifications_by_user_paginated(
                 Platform.Accounts.get_auto_account()
               ).entries

      user2 = Platform.AccountsFixtures.user_fixture()
      %Notification{id: id3} = notification_fixture(%{user_id: user2.id})

      assert [
               %Notification{id: ^id2},
               %Notification{id: ^id1}
             ] =
               Notifications.get_notifications_by_user_paginated(
                 Platform.Accounts.get_auto_account()
               ).entries

      assert [
               %Notification{id: ^id3}
             ] = Notifications.get_notifications_by_user_paginated(user2).entries
    end

    test "has_unread_notifications/1 works correctly" do
      user = Platform.Accounts.get_auto_account()
      other_user = Platform.AccountsFixtures.user_fixture()

      assert Notifications.has_unread_notifications(user) == false
      assert Notifications.has_unread_notifications(other_user) == false

      n1 = notification_fixture(%{user_id: user.id})

      assert Notifications.has_unread_notifications(user) == true
      assert Notifications.has_unread_notifications(other_user) == false

      n2 = notification_fixture(%{user_id: other_user.id})

      assert Notifications.has_unread_notifications(user) == true
      assert Notifications.has_unread_notifications(other_user) == true

      Notifications.update_notification(n1, %{read: true})

      assert Notifications.has_unread_notifications(user) == false
      assert Notifications.has_unread_notifications(other_user) == true

      Notifications.update_notification(n2, %{read: true})

      assert Notifications.has_unread_notifications(user) == false
      assert Notifications.has_unread_notifications(other_user) == false
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
      update_attrs = %{content: "some updated content", read: true}

      assert {:ok, %Notification{} = notification} =
               Notifications.update_notification(notification, update_attrs)

      assert notification.content == "some updated content"
      assert notification.read == true
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
