defmodule Platform.SecurityTest do
  use Platform.DataCase

  alias Platform.Security

  describe "security_modes" do
    alias Platform.Security.SecurityMode

    import Platform.SecurityFixtures

    @invalid_attrs %{description: nil, mode: nil}

    test "list_security_modes/0 returns all security_modes" do
      assert length(Security.list_security_modes()) == 0

      security_mode_fixture()
      assert length(Security.list_security_modes()) == 1

      security_mode_fixture()
      assert length(Security.list_security_modes()) == 2
    end

    test "get_security_mode_state/0 gets the current security mode" do
      assert :normal == Security.get_security_mode_state()

      security_mode_fixture(%{mode: :read_only})
      assert :read_only == Security.get_security_mode_state()

      security_mode_fixture(%{mode: :no_access})
      assert :no_access == Security.get_security_mode_state()

      security_mode_fixture(%{mode: :normal})
      assert :normal == Security.get_security_mode_state()
    end

    test "get_security_mode!/1 returns the security_mode with given id" do
      security_mode = security_mode_fixture()
      assert Security.get_security_mode!(security_mode.id) == security_mode
    end

    test "create_security_mode/1 with valid data creates a security_mode" do
      valid_attrs = %{
        description: "some description",
        mode: :read_only,
        user_id: Platform.Accounts.get_auto_account().id
      }

      assert {:ok, %SecurityMode{} = security_mode} = Security.create_security_mode(valid_attrs)
      assert security_mode.description == "some description"
      assert security_mode.mode == :read_only
      assert security_mode.user_id == Platform.Accounts.get_auto_account().id
    end

    test "create_security_mode/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Security.create_security_mode(@invalid_attrs)
    end

    test "update_security_mode/2 with valid data updates the security_mode" do
      security_mode = security_mode_fixture()
      update_attrs = %{description: "some updated description", mode: :read_only}

      assert {:ok, %SecurityMode{} = security_mode} =
               Security.update_security_mode(security_mode, update_attrs)

      assert security_mode.description == "some updated description"
      assert security_mode.mode == :read_only
    end

    test "update_security_mode/2 with invalid data returns error changeset" do
      security_mode = security_mode_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Security.update_security_mode(security_mode, @invalid_attrs)

      assert security_mode == Security.get_security_mode!(security_mode.id)
    end

    test "delete_security_mode/1 deletes the security_mode" do
      security_mode = security_mode_fixture()
      assert {:ok, %SecurityMode{}} = Security.delete_security_mode(security_mode)
      assert_raise Ecto.NoResultsError, fn -> Security.get_security_mode!(security_mode.id) end
    end

    test "change_security_mode/1 returns a security_mode changeset" do
      security_mode = security_mode_fixture()
      assert %Ecto.Changeset{} = Security.change_security_mode(security_mode)
    end
  end
end
