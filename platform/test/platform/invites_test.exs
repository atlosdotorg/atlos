defmodule Platform.InvitesTest do
  use Platform.DataCase

  alias Platform.Invites

  describe "invites" do
    alias Platform.Invites.Invite

    import Platform.InvitesFixtures
    import Platform.AccountsFixtures

    @invalid_attrs %{active: nil, code: nil}

    test "list_invites/0 returns all invites" do
      assert length(Invites.list_invites()) == 0
      _ = invite_fixture()
      assert length(Invites.list_invites()) == 1
    end

    test "get_invite!/1 returns the invite with given id" do
      invite = invite_fixture()
      assert Invites.get_invite!(invite.id) == invite
    end

    test "get_invite_by_code/1 returns the invite with given code" do
      invite = invite_fixture()
      assert Invites.get_invite_by_code(invite.code) == invite
    end

    test "get_invites_by_user/1 returns the invites with given user" do
      owner = user_fixture()
      assert Enum.empty?(Invites.get_invites_by_user(owner))

      invite_fixture(%{owner_id: owner.id})
      invite_fixture(%{owner_id: owner.id})
      invite_fixture(%{owner_id: owner.id})

      assert length(Invites.get_invites_by_user(owner)) == 3
    end

    test "create_invite/1 with valid data creates a invite" do
      valid_attrs = %{active: true}

      assert {:ok, %Invite{} = invite} = Invites.create_invite(valid_attrs)
      assert invite.active == true
    end

    test "create_invite/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Invites.create_invite(@invalid_attrs)
    end

    test "update_invite/2 with valid data updates the invite" do
      invite = invite_fixture()
      update_attrs = %{active: false}

      assert {:ok, %Invite{} = invite} = Invites.update_invite(invite, update_attrs)
      assert invite.active == false
    end

    test "update_invite/2 with invalid data returns error changeset" do
      invite = invite_fixture()
      assert {:error, %Ecto.Changeset{}} = Invites.update_invite(invite, @invalid_attrs)
      assert invite == Invites.get_invite!(invite.id)
    end

    test "delete_invite/1 deletes the invite" do
      invite = invite_fixture()
      assert {:ok, %Invite{}} = Invites.delete_invite(invite)
      assert_raise Ecto.NoResultsError, fn -> Invites.get_invite!(invite.id) end
    end

    test "change_invite/1 returns a invite changeset" do
      invite = invite_fixture()
      assert %Ecto.Changeset{} = Invites.change_invite(invite)
    end
  end
end
