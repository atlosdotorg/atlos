defmodule Platform.APITest do
  use Platform.DataCase, async: true

  alias Platform.API

  describe "api_tokens" do
    alias Platform.API.APIToken

    import Platform.APIFixtures

    setup do
      %{admin: Platform.AccountsFixtures.admin_user_fixture()}
    end

    @invalid_attrs %{name: nil, description: nil, value: nil}

    test "list_api_tokens/0 returns all api_tokens" do
      api_token_fixture_legacy()
      assert length(API.list_api_tokens()) == 1
    end

    test "get_api_token!/1 returns the api_token with given id" do
      api_token = api_token_fixture_legacy()
      assert API.get_api_token!(api_token.id) == api_token
    end

    test "create_api_token/3 with valid data creates a api_token", %{admin: admin} do
      valid_attrs = %{
        name: "some name",
        description: "some description"
      }

      assert {:ok, %APIToken{} = api_token} =
               API.create_api_token(nil, admin, valid_attrs, legacy: true)

      assert api_token.description == "some description"
    end

    test "create_api_token/3 with invalid data returns error changeset", %{admin: admin} do
      assert {:error, %Ecto.Changeset{}} =
               API.create_api_token(nil, admin, @invalid_attrs)
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

    test "admin_managed?/1 classifies tokens correctly" do
      legacy = api_token_fixture_legacy()
      instance_wide = api_token_fixture_instance_wide_v2()
      project_scoped = api_token_fixture()

      assert APIToken.admin_managed?(legacy)
      assert APIToken.admin_managed?(instance_wide)
      refute APIToken.admin_managed?(project_scoped)
    end

    test "create_api_token/3 cannot be tricked into creating a legacy token via params",
         %{admin: admin} do
      assert {:ok, token} =
               API.create_api_token(
                 nil,
                 admin,
                 %{
                   "name" => "evil",
                   "description" => "tries to set is_legacy via params",
                   "is_legacy" => true
                 },
                 legacy: false
               )

      refute token.is_legacy
    end

    test "create_api_token/3 ignores user-supplied `value` (the secret)", %{admin: admin} do
      attempted_value = "attacker-chosen-token-value"

      {:ok, token} =
        API.create_api_token(
          nil,
          admin,
          %{
            "name" => "no value injection",
            "description" => "tries to set value via params",
            "value" => attempted_value
          }
        )

      refute token.value == attempted_value
    end

    test "create_api_token/3 ignores user-supplied `project_id` when project_or_nil is nil",
         %{admin: admin} do
      project = Platform.ProjectsFixtures.project_fixture()

      {:ok, token} =
        API.create_api_token(
          nil,
          admin,
          %{
            "name" => "no project injection",
            "description" => "tries to set project_id via params",
            "project_id" => project.id
          }
        )

      assert is_nil(token.project_id)
    end

    test "create_api_token/3 enforces :read in permissions", %{admin: admin} do
      assert {:error, changeset} =
               API.create_api_token(
                 nil,
                 admin,
                 %{
                   "name" => "no read",
                   "description" => "should fail",
                   "permissions" => [:edit]
                 }
               )

      refute changeset.valid?
      assert %{permissions: ["API tokens must have read permissions"]} = errors_on(changeset)
    end

    test "create_api_token/3 rejects unknown permissions", %{admin: admin} do
      assert {:error, changeset} =
               API.create_api_token(
                 nil,
                 admin,
                 %{
                   "name" => "bad perm",
                   "description" => "should fail",
                   "permissions" => [:read, :admin]
                 }
               )

      refute changeset.valid?
    end

    test "create_api_token/3 raises when a non-admin tries to create an admin-managed token" do
      non_admin = Platform.AccountsFixtures.user_fixture()

      # Non-admin creator — instance-wide
      assert_raise RuntimeError, fn ->
        API.create_api_token(nil, non_admin, %{
          "name" => "non-admin try",
          "description" => "should fail"
        })
      end

      # Non-admin creator — legacy
      assert_raise RuntimeError, fn ->
        API.create_api_token(
          nil,
          non_admin,
          %{
            "name" => "non-admin legacy try",
            "description" => "should fail"
          },
          legacy: true
        )
      end
    end

    test "create_api_token/3 allows non-admins to create project-scoped tokens" do
      non_admin = Platform.AccountsFixtures.user_fixture()
      project = Platform.ProjectsFixtures.project_fixture()

      assert {:ok, token} =
               API.create_api_token(project, non_admin, %{
                 "name" => "project-scoped, non-admin creator",
                 "description" => "should succeed"
               })

      assert token.project_id == project.id
      refute token.is_legacy
    end

    test "deactivated tokens cannot be reactivated" do
      token = api_token_fixture_instance_wide_v2()
      {:ok, deactivated} = API.deactivate_api_token(token)
      refute deactivated.is_active

      assert {:error, changeset} = API.update_api_token(deactivated, %{is_active: true})
      assert %{is_active: ["Cannot reactivate an inactive token"]} = errors_on(changeset)
    end

    test "a token's project_id cannot be cleared on update" do
      token = api_token_fixture()
      refute is_nil(token.project_id)

      assert {:error, changeset} = API.update_api_token(token, %{project_id: nil})
      assert %{project_id: ["Cannot change a token's project"]} = errors_on(changeset)
    end

    test "a token's project_id cannot be changed to a different project on update" do
      token = api_token_fixture()
      other_project = Platform.ProjectsFixtures.project_fixture()

      assert {:error, changeset} =
               API.update_api_token(token, %{project_id: other_project.id})

      assert %{project_id: ["Cannot change a token's project"]} = errors_on(changeset)
    end

    test "a token's is_legacy cannot be changed on update" do
      token = api_token_fixture()
      refute token.is_legacy

      assert {:error, changeset} = API.update_api_token(token, %{is_legacy: true})
      assert %{is_legacy: ["Cannot change a token's legacy status"]} = errors_on(changeset)
    end
  end
end
