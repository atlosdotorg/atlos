defmodule PlatformWeb.AdminlandLive.UsageDashboardLive do
  @moduledoc """
  The Adminland usage dashboard: instance-wide activity statistics with a
  focus on the people behind them — who is active, who has gone quiet, and
  who may need support. All data comes from `Platform.Statistics`.
  """
  use PlatformWeb, :live_component

  alias Platform.Accounts
  alias Platform.Statistics
  alias VegaLite, as: Vl

  @valid_days [7, 30, 90, 365]

  # Fixed categorical assignment: each kind of activity always renders in the
  # same color, regardless of which kinds are present in the window.
  @kind_order ["Edits", "Comments", "Uploads", "New incidents", "Other", "API"]
  @kind_colors ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300"]

  def update(assigns, socket) do
    days = parse_days(assigns[:params])
    include_api = parse_include_api(assigns[:params])
    opts = [days: days, include_api: include_api]

    activity = Statistics.activity_over_time(opts ++ [bucket: bucket_for(days)])
    signups = Statistics.new_users_over_time(days: days, bucket: bucket_for(days))

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:days, days)
     |> assign(:include_api, include_api)
     |> assign(:stats, Statistics.overview_statistics(opts))
     |> assign(:prior_stats, Statistics.overview_statistics(opts ++ [ending: prior_ending(days)]))
     |> assign(:new_users, Statistics.new_user_statistics(days: days))
     |> assign(:activity_chart, activity_chart(activity))
     |> assign(:signups_chart, signups_chart(signups))
     |> assign(:segments, Statistics.attention_segments())
     |> assign(:top_projects, Statistics.project_rollups(opts) |> Enum.take(5))
     |> assign(
       :top_users,
       Statistics.user_rollups(days: days)
       |> Enum.filter(&(&1.current > 0))
       |> Enum.sort_by(& &1.current, :desc)
       |> Enum.take(5)
     )}
  end

  defp parse_days(%{"days" => days}) do
    case Integer.parse(days) do
      {value, ""} when value in @valid_days -> value
      _ -> 30
    end
  end

  defp parse_days(_), do: 30

  defp parse_include_api(%{"api" => "0"}), do: false
  defp parse_include_api(_), do: true

  # The prior-period window end, truncated to the hour so that the memoized
  # overview query is not re-run on every render.
  defp prior_ending(days) do
    %{
      NaiveDateTime.add(NaiveDateTime.utc_now(), -days * 86_400)
      | minute: 0,
        second: 0,
        microsecond: {0, 0}
    }
  end

  defp bucket_for(days) when days <= 30, do: :day
  defp bucket_for(_days), do: :week

  defp kind(%{api: true}), do: "API"
  defp kind(%{type: :update_attribute}), do: "Edits"
  defp kind(%{type: :comment}), do: "Comments"
  defp kind(%{type: :upload_version}), do: "Uploads"
  defp kind(%{type: :create}), do: "New incidents"
  defp kind(_), do: "Other"

  defp activity_chart([]), do: nil

  defp activity_chart(rows) do
    data =
      rows
      |> Enum.group_by(fn row -> {row.date, kind(row)} end)
      |> Enum.map(fn {{date, kind}, group} ->
        %{date: date, kind: kind, count: group |> Enum.map(& &1.count) |> Enum.sum()}
      end)
      |> Enum.sort_by(& &1.date, NaiveDateTime)

    Vl.new(height: 220, width: "container")
    |> Vl.data_from_values(
      date: Enum.map(data, & &1.date),
      kind: Enum.map(data, & &1.kind),
      count: Enum.map(data, & &1.count)
    )
    |> Vl.mark(:bar)
    |> Vl.encode_field(:x, "date", type: :temporal, title: nil)
    |> Vl.encode_field(:y, "count", type: :quantitative, title: "Updates")
    |> Vl.encode_field(:color, "kind",
      type: :nominal,
      title: nil,
      sort: @kind_order,
      scale: [domain: @kind_order, range: @kind_colors]
    )
    |> Vl.encode(:tooltip, [
      [field: "date", type: :temporal, title: "Date"],
      [field: "kind", type: :nominal, title: "Kind"],
      [field: "count", type: :quantitative, title: "Updates"]
    ])
    |> Vl.to_spec()
    |> Jason.encode!()
  end

  defp signups_chart([]), do: nil

  defp signups_chart(rows) do
    Vl.new(height: 220, width: "container")
    |> Vl.data_from_values(
      date: Enum.map(rows, & &1.date),
      count: Enum.map(rows, & &1.count)
    )
    |> Vl.mark(:bar, color: "#2a78d6")
    |> Vl.encode_field(:x, "date", type: :temporal, title: nil)
    |> Vl.encode_field(:y, "count", type: :quantitative, title: "New users")
    |> Vl.encode(:tooltip, [
      [field: "date", type: :temporal, title: "Date"],
      [field: "count", type: :quantitative, title: "New users"]
    ])
    |> Vl.to_spec()
    |> Jason.encode!()
  end

  defp usage_path(days, include_api) do
    "/adminland/usage?days=#{days}&api=#{if include_api, do: "1", else: "0"}"
  end

  defp range_label(7), do: "7 days"
  defp range_label(30), do: "30 days"
  defp range_label(90), do: "90 days"
  defp range_label(365), do: "1 year"

  defp valid_days, do: @valid_days

  attr(:label, :string, required: true)
  attr(:value, :integer, required: true)
  attr(:prior, :integer, required: true)

  defp stat_tile(assigns) do
    ~H"""
    <div class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-2 bg-white px-4 py-8 sm:px-6">
      <dt class="text-sm font-medium leading-6 text-gray-500"><%= @label %></dt>
      <dd class="w-full flex-none text-3xl font-medium leading-10 tracking-tight text-gray-900">
        <%= Formatter.format_number(@value) %>
      </dd>
      <dd class="text-xs text-gray-500">
        vs. <%= Formatter.format_number(@prior) %> in the prior period
        <%= if @value > @prior do %>
          <span class="text-positive-600 font-medium">&uarr;</span>
        <% end %>
        <%= if @value < @prior do %>
          <span class="text-critical-600 font-medium">&darr;</span>
        <% end %>
      </dd>
    </div>
    """
  end

  attr(:rollup, :map, required: true)
  slot(:detail, required: true)

  defp segment_row(assigns) do
    ~H"""
    <li class="flex items-center justify-between gap-4 py-3">
      <.link navigate={"/profile/" <> @rollup.user.username} class="flex items-center gap-3 min-w-0">
        <img
          class="h-8 w-8 rounded-full shrink-0"
          src={Accounts.get_profile_photo_path(@rollup.user)}
          alt={"Profile photo for #{@rollup.user.username}"}
        />
        <span class="font-medium text-sm text-gray-900 truncate"><%= @rollup.user.username %></span>
        <%= if :muted in (@rollup.user.restrictions || []) do %>
          <span class="chip ~warning @high text-xs">Muted</span>
        <% end %>
      </.link>
      <span class="text-xs text-gray-500 text-right shrink-0">
        <%= render_slot(@detail) %>
      </span>
    </li>
    """
  end

  attr(:title, :string, required: true)
  attr(:subtitle, :string, required: true)
  attr(:rollups, :list, required: true)
  attr(:empty, :string, required: true)
  slot(:detail, required: true)

  defp segment_card(assigns) do
    ~H"""
    <.card>
      <:header>
        <p class="sec-head"><%= @title %></p>
        <p class="sec-subhead"><%= @subtitle %></p>
      </:header>
      <%= if Enum.empty?(@rollups) do %>
        <p class="text-sm text-gray-500"><%= @empty %></p>
      <% else %>
        <ul class="divide-y divide-gray-100">
          <%= for rollup <- Enum.take(@rollups, 10) do %>
            <.segment_row rollup={rollup}>
              <:detail><%= render_slot(@detail, rollup) %></:detail>
            </.segment_row>
          <% end %>
        </ul>
        <%= if length(@rollups) > 10 do %>
          <p class="text-xs text-gray-500 mt-2">
            And <%= length(@rollups) - 10 %> more.
          </p>
        <% end %>
      <% end %>
    </.card>
    """
  end

  def render(assigns) do
    ~H"""
    <section class="max-w-3xl mx-auto">
      <div class="flex flex-col gap-16">
        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div class="flex items-center gap-1" role="group" aria-label="Time range">
            <%= for days <- valid_days() do %>
              <.link
                patch={usage_path(days, @include_api)}
                class={
                  if(days == @days,
                    do:
                      "rounded transition bg-urge-100 text-urge-600 px-3 py-1.5 font-medium text-sm",
                    else:
                      "rounded transition hover:bg-neutral-200 text-neutral-600 px-3 py-1.5 font-medium text-sm"
                  )
                }
              >
                <%= range_label(days) %>
              </.link>
            <% end %>
          </div>
          <.link
            patch={usage_path(@days, not @include_api)}
            class="text-sm text-neutral-600 hover:text-neutral-700 flex items-center gap-2"
          >
            <%= if @include_api do %>
              <Heroicons.check_circle mini class="h-4 w-4 text-urge-600" />
            <% else %>
              <Heroicons.minus_circle mini class="h-4 w-4 opacity-50" />
            <% end %>
            Include API activity
          </.link>
        </div>

        <.card>
          <:header>
            <p class="sec-head">Overview</p>
            <p class="sec-subhead">Usage over the past <%= range_label(@days) %>. Times are UTC.</p>
          </:header>
          <dl class="mx-auto grid grid-cols-1 gap-px bg-gray-900/5 sm:grid-cols-2 lg:grid-cols-4 -m-5">
            <.stat_tile
              label="Contributions"
              value={@stats.total_updates}
              prior={@prior_stats.total_updates}
            />
            <.stat_tile
              label="Active users"
              value={@stats.active_users}
              prior={@prior_stats.active_users}
            />
            <.stat_tile
              label="Active projects"
              value={@stats.active_projects}
              prior={@prior_stats.active_projects}
            />
            <.stat_tile label="New sign-ups" value={@new_users.current} prior={@new_users.prior} />
          </dl>
        </.card>

        <.card>
          <:header>
            <p class="sec-head">Activity over time</p>
            <p class="sec-subhead">
              Contributions per <%= if bucket_for(@days) == :day, do: "day", else: "week" %>, by kind of activity.
            </p>
          </:header>
          <%= if is_nil(@activity_chart) do %>
            <p class="text-sm text-gray-500">No activity in this window.</p>
          <% else %>
            <div id="usage-activity-chart" class="w-full" data-vega={@activity_chart}></div>
          <% end %>
        </.card>

        <.card>
          <:header>
            <p class="sec-head">Sign-ups over time</p>
            <p class="sec-subhead">
              New accounts per <%= if bucket_for(@days) == :day, do: "day", else: "week" %>.
            </p>
          </:header>
          <%= if is_nil(@signups_chart) do %>
            <p class="text-sm text-gray-500">No sign-ups in this window.</p>
          <% else %>
            <div id="usage-signups-chart" class="w-full" data-vega={@signups_chart}></div>
          <% end %>
        </.card>

        <.segment_card
          title="Never got started"
          subtitle="Joined in the last two months but have hardly contributed. A welcome or a pointer to a project may help."
          rollups={@segments.never_started}
          empty="Everyone who joined recently has gotten going. Nice."
        >
          <:detail :let={rollup}>
            Joined <.rel_time time={rollup.user.inserted_at} />
            &middot; <%= rollup.lifetime %> contributions
          </:detail>
        </.segment_card>

        <.segment_card
          title="Gone quiet"
          subtitle="Established contributors with no activity in the last three weeks. May be worth a check-in."
          rollups={@segments.gone_quiet}
          empty="No established contributors have gone quiet."
        >
          <:detail :let={rollup}>
            Last active <.rel_time time={rollup.last_active_at} />
            &middot; <%= rollup.lifetime %> lifetime contributions
          </:detail>
        </.segment_card>

        <.segment_card
          title="Winding down"
          subtitle="Contributors whose activity dropped sharply this month compared to last month."
          rollups={@segments.winding_down}
          empty="Nobody's activity has dropped sharply."
        >
          <:detail :let={rollup}>
            <%= rollup.current %> this month, down from <%= rollup.prior %>
          </:detail>
        </.segment_card>

        <.card>
          <:header>
            <p class="sec-head">Most active projects</p>
            <p class="sec-subhead">
              By contributions over the past <%= range_label(@days) %>. A high top-contributor share can signal that one person is carrying the project.
            </p>
          </:header>
          <%= if Enum.empty?(@top_projects) do %>
            <p class="text-sm text-gray-500">No project activity in this window.</p>
          <% else %>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200 text-sm">
                <thead>
                  <tr class="text-left text-xs text-gray-500 uppercase tracking-wide">
                    <th class="py-2 pr-4 font-medium">Project</th>
                    <th class="py-2 pr-4 font-medium text-right">Contributions</th>
                    <th class="py-2 pr-4 font-medium text-right">Contributors</th>
                    <th class="py-2 font-medium text-right">Top contributor share</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  <%= for rollup <- @top_projects do %>
                    <tr>
                      <td class="py-2 pr-4">
                        <.link
                          navigate={"/projects/" <> rollup.project.id}
                          class="font-medium text-gray-900 hover:text-urge-600"
                        >
                          <%= rollup.project.name %>
                        </.link>
                      </td>
                      <td class="py-2 pr-4 text-right tabular-nums">
                        <%= Formatter.format_number(rollup.total_updates) %>
                      </td>
                      <td class="py-2 pr-4 text-right tabular-nums">
                        <%= Formatter.format_number(rollup.contributor_count) %>
                      </td>
                      <td class="py-2 text-right tabular-nums">
                        <%= if is_nil(rollup.top_contributor_share),
                          do: "—",
                          else: "#{round(rollup.top_contributor_share * 100)}%" %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </.card>

        <.segment_card
          title="Most active people"
          subtitle={"By contributions over the past #{range_label(@days)}."}
          rollups={@top_users}
          empty="No contributor activity in this window."
        >
          <:detail :let={rollup}>
            <%= rollup.current %> contributions &middot; last active
            <.rel_time time={rollup.last_active_at} />
          </:detail>
        </.segment_card>
      </div>
    </section>
    """
  end
end
