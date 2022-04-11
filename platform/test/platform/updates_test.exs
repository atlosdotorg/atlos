defmodule Platform.UpdatesTest do
  use Platform.DataCase

  alias Platform.Updates

  describe "updates" do
    alias Platform.Updates.Update

    import Platform.UpdatesFixtures

    @invalid_attrs %{explanation: nil, modified_attribute: nil, new_value: nil, old_value: nil}

    test "list_updates/0 returns all updates" do
      update = update_fixture()
      assert Updates.list_updates() == [update]
    end

    test "get_update!/1 returns the update with given id" do
      update = update_fixture()
      assert Updates.get_update!(update.id) == update
    end

    test "delete_update/1 deletes the update" do
      update = update_fixture()
      assert {:ok, %Update{}} = Updates.delete_update(update)
      assert_raise Ecto.NoResultsError, fn -> Updates.get_update!(update.id) end
    end

    test "change_update/1 returns a update changeset" do
      update = update_fixture()
      assert %Ecto.Changeset{} = Updates.change_update(update)
    end
  end
end
