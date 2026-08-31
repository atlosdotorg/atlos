defmodule PlatformWeb.AdminlandUsageTest do
  # Not async: Statistics memoizes some queries in a globally shared cache,
  # which we invalidate in setup.
  use PlatformWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Platform.AccountsFixtures
  import Platform.MaterialFixtures
  import Platform.ProjectsFixtures

  alias Platform.Updates

  setup do
    Memoize.invalidate()
    :ok
  end

  test "admins can view the usage dashboard", %{conn: conn} do
    admin = admin_user_fixture()
    media = media_fixture(%{project_id: project_fixture(%{}, owner: admin).id})

    {:ok, _} =
      Updates.change_from_comment(media, admin, %{"explanation" => "A comment."})
      |> Updates.create_update_from_changeset()

    {:ok, _view, html} = conn |> log_in_user(admin) |> live("/adminland/usage")

    assert html =~ "Never got started"
    assert html =~ "Gone quiet"
    assert html =~ "Most active projects"
    assert html =~ "usage-activity-chart"
  end

  test "non-admins cannot view the usage dashboard", %{conn: conn} do
    user = user_fixture()

    assert {:error, {:redirect, %{to: "/"}}} =
             conn |> log_in_user(user) |> live("/adminland/usage")
  end

  test "admins can view the project drill-down", %{conn: conn} do
    admin = admin_user_fixture()
    project = project_fixture(%{name: "Drilldown Project"}, owner: admin)
    media = media_fixture(%{project_id: project.id})

    {:ok, _} =
      Updates.change_from_comment(media, admin, %{"explanation" => "A comment."})
      |> Updates.create_update_from_changeset()

    {:ok, _view, html} =
      conn |> log_in_user(admin) |> live("/adminland/usage/project/#{project.id}")

    assert html =~ "Drilldown Project"
    assert html =~ "Members"
    assert html =~ admin.username
  end

  test "admins can view the person drill-down", %{conn: conn} do
    admin = admin_user_fixture()
    subject = user_fixture()
    media = media_fixture(%{project_id: project_fixture(%{}, owner: subject).id})

    {:ok, _} =
      Updates.change_from_comment(media, subject, %{"explanation" => "A comment."})
      |> Updates.create_update_from_changeset()

    {:ok, _view, html} =
      conn |> log_in_user(admin) |> live("/adminland/usage/user/#{subject.username}")

    assert html =~ subject.username
    assert html =~ "Last signed in"
    assert html =~ "Recent activity"
  end

  test "non-admins cannot view the drill-downs", %{conn: conn} do
    user = user_fixture()
    subject = user_fixture()

    assert {:error, {:redirect, %{to: "/"}}} =
             conn |> log_in_user(user) |> live("/adminland/usage/user/#{subject.username}")
  end
end
