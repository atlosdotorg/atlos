defmodule Platform.APITest do
  use Platform.DataCase, async: true

  alias Platform.API

  describe "api_tokens" do
    alias Platform.API.APIToken

    import Platform.APIFixtures

    @invalid_attrs %{description: nil, value: nil}

    test "list_api_tokens/0 returns all api_tokens" do
      api_token = api_token_fixture()
      assert API.list_api_tokens() == [api_token]
    end

    test "get_api_token!/1 returns the api_token with given id" do
      api_token = api_token_fixture()
      assert API.get_api_token!(api_token.id) == api_token
    end

    test "create_api_token/1 with valid data creates a api_token" do
      valid_attrs = %{description: "some description"}

      assert {:ok, %APIToken{} = api_token} = API.create_api_token(valid_attrs)
      assert api_token.description == "some description"
    end

    test "create_api_token/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = API.create_api_token(@invalid_attrs)
    end

    test "update_api_token/2 with valid data updates the api_token" do
      api_token = api_token_fixture()
      update_attrs = %{description: "some updated description"}

      assert {:ok, %APIToken{} = api_token} = API.update_api_token(api_token, update_attrs)
      assert api_token.description == "some updated description"
    end

    test "update_api_token/2 with invalid data returns error changeset" do
      api_token = api_token_fixture()
      assert {:error, %Ecto.Changeset{}} = API.update_api_token(api_token, @invalid_attrs)
      assert api_token == API.get_api_token!(api_token.id)
    end

    test "delete_api_token/1 deletes the api_token" do
      api_token = api_token_fixture()
      assert {:ok, %APIToken{}} = API.delete_api_token(api_token)
      assert_raise Ecto.NoResultsError, fn -> API.get_api_token!(api_token.id) end
    end

    test "change_api_token/1 returns a api_token changeset" do
      api_token = api_token_fixture()
      assert %Ecto.Changeset{} = API.change_api_token(api_token)
    end
  end
end
