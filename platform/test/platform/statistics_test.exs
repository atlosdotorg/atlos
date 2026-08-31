defmodule Platform.StatisticsTest do
  # Not async: Statistics memoizes some queries in a globally shared cache,
  # which we invalidate in setup.
  use Platform.DataCase, async: false

  alias Platform.Accounts.User
  alias Platform.Repo
  alias Platform.Statistics
  alias Platform.Updates
  alias Platform.Updates.Update

  import Platform.AccountsFixtures
  import Platform.MaterialFixtures
  import Platform.ProjectsFixtures

  setup do
    Memoize.invalidate()
    :ok
  end

  defp days_ago(days) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(-days * 86_400)
    |> NaiveDateTime.truncate(:second)
  end

  defp comment!(media, user, opts \\ []) do
    {:ok, update} =
      Updates.change_from_comment(media, user, %{"explanation" => "A comment."})
      |> Updates.create_update_from_changeset()

    case Keyword.get(opts, :at) do
      nil ->
        update

      timestamp ->
        {1, _} =
          Repo.update_all(from(u in Update, where: u.id == ^update.id),
            set: [inserted_at: timestamp]
          )

        %{update | inserted_at: timestamp}
    end
  end

  defp backdate_user!(user, timestamp) do
    {1, _} =
      Repo.update_all(from(u in User, where: u.id == ^user.id), set: [inserted_at: timestamp])

    %{user | inserted_at: timestamp}
  end

  describe "overview_statistics/1" do
    test "counts distinct users, incidents, and projects within the window" do
      user_one = user_fixture()
      user_two = user_fixture()
      media_one = media_fixture(%{project_id: project_fixture(%{}, owner: user_one).id})
      media_two = media_fixture(%{project_id: project_fixture(%{}, owner: user_two).id})

      comment!(media_one, user_one)
      comment!(media_one, user_one)
      comment!(media_two, user_two)
      # Outside the window; should not be counted
      comment!(media_two, user_two, at: days_ago(100))

      stats = Statistics.overview_statistics(days: 14)

      assert stats.total_updates == 3
      assert stats.active_users == 2
      assert stats.active_incidents == 2
      assert stats.active_projects == 2
    end

    test "supports an explicit window end for prior-period comparisons" do
      user = user_fixture()
      media = media_fixture(%{project_id: project_fixture(%{}, owner: user).id})

      comment!(media, user)
      comment!(media, user, at: days_ago(20))

      stats = Statistics.overview_statistics(days: 14, ending: days_ago(14))

      assert stats.total_updates == 1
      assert stats.active_users == 1
    end
  end

  describe "new_user_statistics/1" do
    test "counts sign-ups in the current and prior windows" do
      _current = user_fixture()
      _prior = user_fixture() |> backdate_user!(days_ago(20))
      _older = user_fixture() |> backdate_user!(days_ago(100))

      stats = Statistics.new_user_statistics(days: 14)

      assert stats.current == 1
      assert stats.prior == 1
    end
  end

  describe "new_users_over_time/1" do
    test "buckets sign-ups by day" do
      _one = user_fixture()
      _two = user_fixture()
      _outside = user_fixture() |> backdate_user!(days_ago(100))

      assert [%{count: 2}] = Statistics.new_users_over_time(days: 14, bucket: :day)
    end
  end

  describe "active_projects/1" do
    test "returns only projects with activity in the window" do
      user = user_fixture()
      active_project = project_fixture(%{}, owner: user)
      quiet_project = project_fixture(%{}, owner: user)
      active_media = media_fixture(%{project_id: active_project.id})
      quiet_media = media_fixture(%{project_id: quiet_project.id})

      comment!(active_media, user)
      comment!(quiet_media, user, at: days_ago(100))

      assert Statistics.active_projects(days: 14) |> Enum.map(& &1.id) == [active_project.id]
    end
  end

  describe "activity_over_time/1" do
    test "buckets update counts by day and type" do
      user = user_fixture()
      media = media_fixture(%{project_id: project_fixture(%{}, owner: user).id})

      comment!(media, user)
      comment!(media, user)
      comment!(media, user, at: days_ago(3))

      buckets = Statistics.activity_over_time(days: 14, bucket: :day)

      assert [
               %{type: :comment, api: false, count: 1},
               %{type: :comment, api: false, count: 2}
             ] = buckets
    end
  end

  describe "user_rollups/1" do
    test "computes current, prior, and lifetime counts and last activity" do
      user = user_fixture()
      media = media_fixture(%{project_id: project_fixture(%{}, owner: user).id})

      comment!(media, user)
      comment!(media, user, at: days_ago(40))
      comment!(media, user, at: days_ago(200))

      rollup =
        Statistics.user_rollups(days: 30)
        |> Enum.find(&(&1.user.id == user.id))

      assert rollup.current == 1
      assert rollup.prior == 1
      assert rollup.lifetime == 3
      assert NaiveDateTime.diff(NaiveDateTime.utc_now(), rollup.last_active_at) < 60
    end

    test "includes users with no activity" do
      user = user_fixture()

      rollup =
        Statistics.user_rollups()
        |> Enum.find(&(&1.user.id == user.id))

      assert rollup.current == 0
      assert rollup.lifetime == 0
      assert is_nil(rollup.last_active_at)
    end
  end

  describe "attention_segments/1" do
    test "surfaces recent joiners who never got started" do
      stuck = user_fixture() |> backdate_user!(days_ago(10))
      # Too new to be considered stuck
      _fresh = user_fixture()

      segments = Statistics.attention_segments()

      assert Enum.map(segments.never_started, & &1.user.id) == [stuck.id]
    end

    test "surfaces contributors who have gone quiet" do
      user = user_fixture() |> backdate_user!(days_ago(120))
      media = media_fixture(%{project_id: project_fixture(%{}, owner: user).id})
      for _ <- 1..12, do: comment!(media, user, at: days_ago(70))

      segments = Statistics.attention_segments(days: 30)

      assert Enum.map(segments.gone_quiet, & &1.user.id) == [user.id]
      # All their activity predates the prior window, so they are not winding down
      assert segments.winding_down == []
    end

    test "surfaces contributors who are winding down" do
      user = user_fixture() |> backdate_user!(days_ago(120))
      media = media_fixture(%{project_id: project_fixture(%{}, owner: user).id})
      for _ <- 1..12, do: comment!(media, user, at: days_ago(40))
      comment!(media, user)

      segments = Statistics.attention_segments(days: 30)

      assert Enum.map(segments.winding_down, & &1.user.id) == [user.id]
      # They were active moments ago, so they have not gone quiet
      assert segments.gone_quiet == []
    end

    test "excludes suspended users" do
      user = user_fixture() |> backdate_user!(days_ago(120))
      media = media_fixture(%{project_id: project_fixture(%{}, owner: user).id})
      for _ <- 1..12, do: comment!(media, user, at: days_ago(70))

      {:ok, _} = Platform.Accounts.update_user_admin(user, %{restrictions: [:suspended]})

      segments = Statistics.attention_segments(days: 30)

      assert segments.gone_quiet == []
    end
  end

  describe "project_rollups/1" do
    test "computes totals, contributor counts, and load concentration" do
      owner = user_fixture()
      editor = user_fixture()
      project = project_fixture(%{}, owner: owner)
      media = media_fixture(%{project_id: project.id}, for_user: editor)

      for _ <- 1..3, do: comment!(media, owner)
      comment!(media, editor)

      [rollup] = Statistics.project_rollups(days: 14)

      assert rollup.project.id == project.id
      assert rollup.total_updates == 4
      assert rollup.contributor_count == 2
      assert rollup.top_contributor_share == 0.75
    end
  end

  describe "activity_over_time/1 filters" do
    test "supports project and user filters" do
      user = user_fixture()
      other = user_fixture()
      project = project_fixture(%{}, owner: user)
      other_project = project_fixture(%{}, owner: other)
      media = media_fixture(%{project_id: project.id})
      other_media = media_fixture(%{project_id: other_project.id})

      comment!(media, user)
      comment!(other_media, other)

      assert [%{count: 1}] =
               Statistics.activity_over_time(days: 14, bucket: :day, project_id: project.id)

      assert [%{count: 1}] =
               Statistics.activity_over_time(days: 14, bucket: :day, user_id: user.id)
    end
  end

  describe "user_project_rollups/2" do
    test "returns per-project counts for one user's memberships" do
      user = user_fixture()
      project = project_fixture(%{}, owner: user)
      other_project = project_fixture(%{}, owner: user)
      media = media_fixture(%{project_id: project.id})
      _quiet_media = media_fixture(%{project_id: other_project.id})

      comment!(media, user)
      comment!(media, user)

      rollups = Statistics.user_project_rollups(user.id, days: 14)

      assert length(rollups) == 2
      active = Enum.find(rollups, &(&1.project.id == project.id))
      quiet = Enum.find(rollups, &(&1.project.id == other_project.id))

      assert active.current == 2
      assert active.lifetime == 2
      assert active.membership.role == :owner
      assert quiet.current == 0
      assert is_nil(quiet.last_active_at)
    end
  end

  describe "last_session_at/1" do
    test "returns the most recent session, or nil without one" do
      user = user_fixture()
      assert is_nil(Statistics.last_session_at(user.id))

      _token = Platform.Accounts.generate_user_session_token(user)
      assert NaiveDateTime.diff(NaiveDateTime.utc_now(), Statistics.last_session_at(user.id)) < 60
    end
  end

  describe "explore_series/1 and explore_totals/1" do
    test "split by project counts per project" do
      user = user_fixture()
      project = project_fixture(%{}, owner: user)
      other_project = project_fixture(%{}, owner: user)
      media = media_fixture(%{project_id: project.id})
      other_media = media_fixture(%{project_id: other_project.id})

      comment!(media, user)
      comment!(media, user)
      comment!(other_media, user)

      series = Statistics.explore_series(days: 14, bucket: :day, split: :project)
      by_project = Map.new(series, &{&1.project_id, &1.count})

      assert by_project[project.id] == 2
      assert by_project[other_project.id] == 1

      totals = Statistics.explore_totals(days: 14, split: :project)
      assert [%{current: 2}, %{current: 1}] = totals
    end

    test "split by kind separates types, filters restrict" do
      user = user_fixture()
      media = media_fixture(%{project_id: project_fixture(%{}, owner: user).id})
      comment!(media, user)

      assert [%{type: :comment, api: false, count: 1}] =
               Statistics.explore_series(days: 14, bucket: :day, split: :kind)

      assert [] =
               Statistics.explore_series(
                 days: 14,
                 bucket: :day,
                 split: :kind,
                 filter_kind: :upload_version
               )

      assert [%{count: 1}] =
               Statistics.explore_series(
                 days: 14,
                 bucket: :day,
                 split: :none,
                 filter_source: :human
               )

      assert [] = Statistics.explore_series(days: 14, bucket: :day, filter_source: :api)
    end

    test "the active metric counts distinct people" do
      user_one = user_fixture()
      user_two = user_fixture()
      project = project_fixture(%{}, owner: user_one)
      media = media_fixture(%{project_id: project.id}, for_user: user_two)

      comment!(media, user_one)
      comment!(media, user_one)
      comment!(media, user_two)

      assert [%{count: 2}] = Statistics.explore_series(days: 14, bucket: :day, metric: :active)

      assert [%{current: 2, prior: 0}] = Statistics.explore_totals(days: 14, metric: :active)
    end

    test "totals compute prior-period counts" do
      user = user_fixture()
      media = media_fixture(%{project_id: project_fixture(%{}, owner: user).id})

      comment!(media, user)
      comment!(media, user, at: days_ago(20))

      assert [%{current: 1, prior: 1}] = Statistics.explore_totals(days: 14)
    end
  end

  describe "project_member_rollups/2" do
    test "counts only activity within the given project" do
      owner = user_fixture()
      project = project_fixture(%{}, owner: owner)
      other_project = project_fixture(%{}, owner: owner)
      media = media_fixture(%{project_id: project.id})
      other_media = media_fixture(%{project_id: other_project.id})

      comment!(media, owner)
      comment!(media, owner)
      comment!(other_media, owner)

      [rollup] = Statistics.project_member_rollups(project.id, days: 14)

      assert rollup.user.id == owner.id
      assert rollup.membership.role == :owner
      assert rollup.current == 2
      assert rollup.lifetime == 2
    end
  end
end
