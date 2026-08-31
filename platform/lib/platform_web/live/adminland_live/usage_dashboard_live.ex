defmodule PlatformWeb.AdminlandLive.UsageDashboardLive do
  @moduledoc """
  The Adminland usage dashboard overview: instance-wide activity statistics
  with a focus on the people behind them — who is active, who has gone quiet,
  and who may need support. All data comes from `Platform.Statistics`.
  """
  use PlatformWeb, :live_component

  import PlatformWeb.AdminlandLive.UsageComponents

  alias Platform.Statistics
  alias PlatformWeb.AdminlandLive.UsageComponents

  def update(assigns, socket) do
    days = parse_days(assigns[:params])
    include_api = parse_include_api(assigns[:params])
    opts = [days: days, include_api: include_api]
    bucket = bucket_for(days)

    activity = Statistics.activity_over_time(opts ++ [bucket: bucket])
    signups = Statistics.new_users_over_time(days: days, bucket: bucket)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:days, days)
     |> assign(:include_api, include_api)
     |> assign(:stats, Statistics.overview_statistics(opts))
     |> assign(:prior_stats, Statistics.overview_statistics(opts ++ [ending: prior_ending(days)]))
     |> assign(:new_users, Statistics.new_user_statistics(days: days))
     |> assign(:activity_chart, UsageComponents.activity_chart_spec(activity, bucket))
     |> assign(
       :signups_chart,
       UsageComponents.single_series_chart_spec(signups, "New users", bucket)
     )
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

  attr(:title, :string, required: true)
  attr(:subtitle, :string, required: true)
  attr(:rollups, :list, required: true)
  attr(:empty, :string, required: true)
  attr(:days, :integer, required: true)
  attr(:include_api, :boolean, required: true)
  slot(:icon, required: true)
  slot(:detail, required: true)

  defp segment_card(assigns) do
    ~H"""
    <.card>
      <:header>
        <div class="flex items-center gap-2">
          <span class="flex items-center justify-center h-7 w-7 rounded-md bg-urge-50 text-urge-600">
            <%= render_slot(@icon) %>
          </span>
          <p class="sec-head"><%= @title %></p>
          <span :if={not Enum.empty?(@rollups)} class="chip ~neutral">
            <%= length(@rollups) %>
          </span>
        </div>
        <p class="sec-subhead"><%= @subtitle %></p>
      </:header>
      <%= if Enum.empty?(@rollups) do %>
        <p class="text-sm text-gray-500"><%= @empty %></p>
      <% else %>
        <ul class="divide-y divide-gray-100">
          <%= for rollup <- Enum.take(@rollups, 10) do %>
            <.person_row
              user={rollup.user}
              navigate={usage_path(@days, @include_api, "/user/#{rollup.user.username}")}
            >
              <:detail><%= render_slot(@detail, rollup) %></:detail>
            </.person_row>
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
        <.range_picker days={@days} include_api={@include_api} />

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
          days={@days}
          include_api={@include_api}
        >
          <:icon><Heroicons.user_plus mini class="h-4 w-4" /></:icon>
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
          days={@days}
          include_api={@include_api}
        >
          <:icon><Heroicons.moon mini class="h-4 w-4" /></:icon>
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
          days={@days}
          include_api={@include_api}
        >
          <:icon><Heroicons.arrow_trending_down mini class="h-4 w-4" /></:icon>
          <:detail :let={rollup}>
            <%= rollup.current %> this month, down from <%= rollup.prior %>
          </:detail>
        </.segment_card>

        <.card>
          <:header>
            <div class="flex items-center gap-2">
              <span class="flex items-center justify-center h-7 w-7 rounded-md bg-urge-50 text-urge-600">
                <Heroicons.trophy mini class="h-4 w-4" />
              </span>
              <p class="sec-head">Most active projects</p>
            </div>
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
                      <td class="py-2.5 pr-4">
                        <.link
                          navigate={usage_path(@days, @include_api, "/project/#{rollup.project.id}")}
                          class="font-medium text-gray-900 hover:text-urge-600 transition flex items-center gap-2"
                        >
                          <span
                            class="h-2.5 w-2.5 rounded-full shrink-0"
                            style={"background-color: #{rollup.project.color || "#60a5fa"}"}
                          >
                          </span>
                          <%= rollup.project.name %>
                        </.link>
                      </td>
                      <td class="py-2.5 pr-4 text-right tabular-nums">
                        <%= Formatter.format_number(rollup.total_updates) %>
                      </td>
                      <td class="py-2.5 pr-4 text-right tabular-nums">
                        <%= Formatter.format_number(rollup.contributor_count) %>
                      </td>
                      <td class="py-2.5 text-right tabular-nums">
                        <%= if is_nil(rollup.top_contributor_share) do %>
                          &mdash;
                        <% else %>
                          <.share_meter share={rollup.top_contributor_share} />
                        <% end %>
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
          days={@days}
          include_api={@include_api}
        >
          <:icon><Heroicons.fire mini class="h-4 w-4" /></:icon>
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
