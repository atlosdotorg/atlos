defmodule Platform.Statistics do
  @moduledoc """
  Aggregate usage statistics for the admin usage dashboard.

  All functions compute their results with grouped SQL queries against the
  `updates` table (the durable activity log), rather than loading updates into
  memory. Timestamps are naive UTC, matching the rest of the schema.

  Most functions take a keyword list of options:

  - `days`: the length of the activity window in days (default 30).
  - `include_api`: whether to include updates made via API tokens (i.e.,
    updates with no `user_id`). Defaults to `true` for instance-wide counts.
    Per-user rollups and attention segments always exclude API activity.

  The updates of the automation account (username "Atlos") are excluded from
  per-user rollups and attention segments, since they do not represent a
  human contributor.
  """

  use Memoize
  import Ecto.Query, warn: false

  alias Platform.Repo
  alias Platform.Accounts.User
  alias Platform.Projects.Project
  alias Platform.Projects.ProjectMembership
  alias Platform.Updates.Update

  @default_window_days 30

  # Thresholds for the attention segments. These are starting points, expected
  # to be tuned once the dashboard has seen real use.
  @never_started_min_age_days 7
  @never_started_max_age_days 60
  @never_started_max_lifetime_updates 3
  @gone_quiet_min_lifetime_updates 10
  @gone_quiet_days 21
  @winding_down_min_prior_updates 10
  @winding_down_ratio 0.4

  @automation_username "Atlos"

  @doc """
  Instance-wide counts of activity in the window: total updates, distinct
  contributing users, distinct incidents, and distinct projects.

  Memoized for one minute, since this powers always-on dashboard tiles.
  """
  defmemo overview_statistics(opts \\ []), expires_in: 60_000 do
    from(u in Update,
      as: :update,
      join: m in assoc(u, :media),
      select: %{
        total_updates: count(u.id),
        active_users: count(u.user_id, :distinct),
        active_incidents: count(u.media_id, :distinct),
        active_projects: count(m.project_id, :distinct)
      }
    )
    |> in_window(opts)
    |> maybe_exclude_api(opts)
    |> Repo.one()
  end

  @doc """
  Projects with at least one update in the window, most recently active first.

  Memoized for one minute.
  """
  defmemo active_projects(opts \\ []), expires_in: 60_000 do
    from(p in Project,
      join: m in assoc(p, :media),
      join: u in assoc(m, :updates),
      as: :update,
      group_by: p.id,
      order_by: [desc: max(u.inserted_at)],
      select: p
    )
    |> in_window(opts)
    |> maybe_exclude_api(opts)
    |> Repo.all()
  end

  @doc """
  Update counts over time, bucketed by `:day`, `:week`, or `:month` (the
  `bucket` option; defaults to `:week`), and broken out by update type and by
  whether the update came from an API token.

  Returns a list of `%{date: naive_datetime, type: atom, api: boolean,
  count: integer}`, ordered by date. Buckets with no activity are omitted.
  """
  def activity_over_time(opts \\ []) do
    bucket =
      case Keyword.get(opts, :bucket, :week) do
        b when b in [:day, :week, :month] -> Atom.to_string(b)
      end

    # The bucketed date is referenced by select-list position ("GROUP BY 1"):
    # since the bucket is a query parameter, Postgres cannot tell that a
    # repeated date_trunc expression in GROUP BY is the same one.
    from(u in Update,
      as: :update,
      group_by: [fragment("1"), u.type, is_nil(u.user_id)],
      order_by: fragment("1"),
      select: %{
        date: fragment("date_trunc(?::text, ?)", ^bucket, u.inserted_at),
        type: u.type,
        api: is_nil(u.user_id),
        count: count(u.id)
      }
    )
    |> in_window(opts)
    |> maybe_exclude_api(opts)
    |> Repo.all()
  end

  @doc """
  Per-user activity rollups for every human user: updates in the current
  window (`current`), updates in the equally sized window before it (`prior`),
  lifetime updates, and the time of their most recent update.

  Returns a list of `%{user: %User{}, current: integer, prior: integer,
  lifetime: integer, last_active_at: naive_datetime | nil}`. API activity is
  excluded; so is the automation account.
  """
  def user_rollups(opts \\ []) do
    window_start = window_start(opts)
    prior_start = NaiveDateTime.add(window_start, -window_days(opts) * 86_400)

    from(user in User,
      left_join: up in Update,
      on: up.user_id == user.id,
      where: user.username != @automation_username,
      group_by: user.id,
      select: %{
        user: user,
        lifetime: count(up.id),
        last_active_at: max(up.inserted_at),
        current: fragment("count(*) filter (where ? >= ?)", up.inserted_at, ^window_start),
        prior:
          fragment(
            "count(*) filter (where ? >= ? and ? < ?)",
            up.inserted_at,
            ^prior_start,
            up.inserted_at,
            ^window_start
          )
      }
    )
    |> Repo.all()
  end

  @doc """
  The attention segments for the admin usage dashboard: the people a community
  manager may want to check in with. Returns a map with three lists of rollups
  (see `user_rollups/1`):

  - `never_started`: accounts between #{@never_started_min_age_days} and
    #{@never_started_max_age_days} days old with fewer than
    #{@never_started_max_lifetime_updates} lifetime updates, newest first.
  - `gone_quiet`: contributors with at least #{@gone_quiet_min_lifetime_updates}
    lifetime updates and no activity in the last #{@gone_quiet_days} days, most
    recently active first.
  - `winding_down`: contributors whose updates in the current window fell below
    #{trunc(@winding_down_ratio * 100)}% of the prior window (with at least
    #{@winding_down_min_prior_updates} prior updates), steepest decline first.

  Suspended users are excluded from all segments, since they cannot contribute.
  """
  def attention_segments(opts \\ []) do
    now = NaiveDateTime.utc_now()
    newest_start = NaiveDateTime.add(now, -@never_started_min_age_days * 86_400)
    oldest_start = NaiveDateTime.add(now, -@never_started_max_age_days * 86_400)
    quiet_cutoff = NaiveDateTime.add(now, -@gone_quiet_days * 86_400)

    rollups =
      user_rollups(opts)
      |> Enum.reject(fn %{user: user} -> :suspended in (user.restrictions || []) end)

    %{
      never_started:
        rollups
        |> Enum.filter(fn %{user: user, lifetime: lifetime} ->
          NaiveDateTime.compare(user.inserted_at, newest_start) == :lt and
            NaiveDateTime.compare(user.inserted_at, oldest_start) == :gt and
            lifetime < @never_started_max_lifetime_updates
        end)
        |> Enum.sort_by(fn %{user: user} -> user.inserted_at end, {:desc, NaiveDateTime}),
      gone_quiet:
        rollups
        |> Enum.filter(fn %{lifetime: lifetime, last_active_at: last_active_at} ->
          lifetime >= @gone_quiet_min_lifetime_updates and
            not is_nil(last_active_at) and
            NaiveDateTime.compare(last_active_at, quiet_cutoff) == :lt
        end)
        |> Enum.sort_by(& &1.last_active_at, {:desc, NaiveDateTime}),
      winding_down:
        rollups
        |> Enum.filter(fn %{current: current, prior: prior} ->
          prior >= @winding_down_min_prior_updates and current < prior * @winding_down_ratio
        end)
        |> Enum.sort_by(fn %{current: current, prior: prior} -> current / prior end)
    }
  end

  @doc """
  Per-project activity rollups for the window: total updates, distinct human
  contributors, and the share of updates made by the busiest contributor (a
  load-concentration/burnout signal; `nil` when the project had no human
  activity). Ordered by total updates, descending.

  Returns a list of `%{project: %Project{}, total_updates: integer,
  contributor_count: integer, top_contributor_share: float | nil}`.
  """
  def project_rollups(opts \\ []) do
    per_contributor =
      from(u in Update,
        as: :update,
        join: m in assoc(u, :media),
        where: not is_nil(m.project_id),
        group_by: [m.project_id, u.user_id],
        select: %{project_id: m.project_id, user_id: u.user_id, count: count(u.id)}
      )
      |> in_window(opts)
      |> maybe_exclude_api(opts)
      |> Repo.all()

    rollups_by_project =
      per_contributor
      |> Enum.group_by(& &1.project_id)
      |> Map.new(fn {project_id, rows} ->
        total = rows |> Enum.map(& &1.count) |> Enum.sum()
        human_rows = Enum.reject(rows, &is_nil(&1.user_id))

        top_share =
          case human_rows do
            [] -> nil
            _ -> Enum.max_by(human_rows, & &1.count).count / total
          end

        {project_id,
         %{
           total_updates: total,
           contributor_count: length(human_rows),
           top_contributor_share: top_share
         }}
      end)

    from(p in Project, where: p.id in ^Map.keys(rollups_by_project))
    |> Repo.all()
    |> Enum.map(fn project -> Map.put(rollups_by_project[project.id], :project, project) end)
    |> Enum.sort_by(& &1.total_updates, :desc)
  end

  @doc """
  Activity rollups for every member of the given project, counting only their
  updates within that project. Least recently active members first, so the
  people most likely to need attention surface at the top.

  Returns a list of `%{membership: %ProjectMembership{}, user: %User{},
  current: integer, prior: integer, lifetime: integer,
  last_active_at: naive_datetime | nil}`.
  """
  def project_member_rollups(project_id, opts \\ []) do
    window_start = window_start(opts)
    prior_start = NaiveDateTime.add(window_start, -window_days(opts) * 86_400)

    project_updates =
      from(u in Update,
        join: m in assoc(u, :media),
        where: m.project_id == ^project_id,
        select: %{id: u.id, user_id: u.user_id, inserted_at: u.inserted_at}
      )

    from(pm in ProjectMembership,
      where: pm.project_id == ^project_id,
      join: user in assoc(pm, :user),
      left_join: up in subquery(project_updates),
      on: up.user_id == user.id,
      group_by: [pm.id, user.id],
      order_by: [asc_nulls_first: max(up.inserted_at)],
      select: %{
        membership: pm,
        user: user,
        lifetime: count(up.id),
        last_active_at: max(up.inserted_at),
        current: fragment("count(*) filter (where ? >= ?)", up.inserted_at, ^window_start),
        prior:
          fragment(
            "count(*) filter (where ? >= ? and ? < ?)",
            up.inserted_at,
            ^prior_start,
            up.inserted_at,
            ^window_start
          )
      }
    )
    |> Repo.all()
  end

  defp window_days(opts), do: Keyword.get(opts, :days, @default_window_days)

  defp window_start(opts) do
    NaiveDateTime.add(NaiveDateTime.utc_now(), -window_days(opts) * 86_400)
  end

  defp in_window(query, opts) do
    window_start = window_start(opts)
    where(query, [update: u], u.inserted_at >= ^window_start)
  end

  defp maybe_exclude_api(query, opts) do
    if Keyword.get(opts, :include_api, true) do
      query
    else
      where(query, [update: u], not is_nil(u.user_id))
    end
  end
end
