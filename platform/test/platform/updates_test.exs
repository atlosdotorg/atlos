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

    test "create_update/1 with valid data creates a update" do
      valid_attrs = %{explanation: "some explanation", modified_attribute: "some modified_attribute", new_value: "some new_value", old_value: "some old_value"}

      assert {:ok, %Update{} = update} = Updates.create_update(valid_attrs)
      assert update.explanation == "some explanation"
      assert update.modified_attribute == "some modified_attribute"
      assert update.new_value == "some new_value"
      assert update.old_value == "some old_value"
    end

    test "create_update/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Updates.create_update(@invalid_attrs)
    end

    test "update_update/2 with valid data updates the update" do
      update = update_fixture()
      update_attrs = %{explanation: "some updated explanation", modified_attribute: "some updated modified_attribute", new_value: "some updated new_value", old_value: "some updated old_value"}

      assert {:ok, %Update{} = update} = Updates.update_update(update, update_attrs)
      assert update.explanation == "some updated explanation"
      assert update.modified_attribute == "some updated modified_attribute"
      assert update.new_value == "some updated new_value"
      assert update.old_value == "some updated old_value"
    end

    test "update_update/2 with invalid data returns error changeset" do
      update = update_fixture()
      assert {:error, %Ecto.Changeset{}} = Updates.update_update(update, @invalid_attrs)
      assert update == Updates.get_update!(update.id)
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
