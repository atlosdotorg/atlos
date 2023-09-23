defmodule Platform.APITest do
  use Platform.DataCase, async: true

  alias Platform.API

  describe "api_tokens" do
    alias Platform.API.APIToken

    import Platform.APIFixtures

    @invalid_attrs %{name: nil, description: nil, value: nil}

    test "list_api_tokens/0 returns all api_tokens" do
      api_token = api_token_fixture_legacy()
      assert API.list_api_tokens() == [api_token]
    end

    test "get_api_token!/1 returns the api_token with given id" do
      api_token = api_token_fixture_legacy()
      assert API.get_api_token!(api_token.id) == api_token
    end

    test "create_api_token/1 with valid data creates a api_token" do
      valid_attrs = %{
        name: "some name",
        description: "some description",
        creator_id: Platform.Accounts.get_auto_account().id
      }

      assert {:ok, %APIToken{} = api_token} = API.create_api_token(valid_attrs, legacy: true)
      assert api_token.description == "some description"
    end

    test "create_api_token/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = API.create_api_token(@invalid_attrs)
    end

    test "update_api_token/2 with valid data updates the api_token" do
      api_token = api_token_fixture_legacy()
      update_attrs = %{description: "some updated description"}

      assert {:ok, %APIToken{} = api_token} = API.update_api_token(api_token, update_attrs)
      assert api_token.description == "some updated description"
    end

    test "update_api_token/2 with invalid data returns error changeset" do
      api_token = api_token_fixture_legacy()
      assert {:error, %Ecto.Changeset{}} = API.update_api_token(api_token, @invalid_attrs)
      assert api_token == API.get_api_token!(api_token.id)
    end

    test "delete_api_token/1 deletes the api_token" do
      api_token = api_token_fixture_legacy()
      assert {:ok, %APIToken{}} = API.delete_api_token(api_token)
      assert_raise Ecto.NoResultsError, fn -> API.get_api_token!(api_token.id) end
    end

    test "change_api_token/1 returns a api_token changeset" do
      api_token = api_token_fixture_legacy()
      assert %Ecto.Changeset{} = API.change_api_token(api_token)
    end
  end
end
