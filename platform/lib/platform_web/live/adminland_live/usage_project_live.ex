defmodule PlatformWeb.AdminlandLive.UsageProjectLive do
  @moduledoc """
  Project drill-down for the Adminland usage dashboard: activity over time
  within one project, incident status breakdown, and a member roster sorted so
  the least recently active members — the people most likely to need
  attention — surface first.
  """
  use PlatformWeb, :live_component

  import PlatformWeb.AdminlandLive.UsageComponents

  alias Platform.Material
  alias Platform.Projects
  alias Platform.Statistics
  alias PlatformWeb.AdminlandLive.UsageComponents

  def update(assigns, socket) do
    days = parse_days(assigns[:params])
    include_api = parse_include_api(assigns[:params])
    bucket = bucket_for(days)
    project = Projects.get_project!(assigns.params["id"])
    opts = [days: days, include_api: include_api, project_id: project.id]

    activity = Statistics.activity_over_time(opts ++ [bucket: bucket])
    members = Statistics.project_member_rollups(project.id, days: days)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:days, days)
     |> assign(:include_api, include_api)
     |> assign(:project, project)
     |> assign(:stats, Statistics.overview_statistics(opts))
     |> assign(:activity_chart, UsageComponents.activity_chart_spec(activity, bucket))
     |> assign(:members, members)
     |> assign(
       :status_overview,
       Material.status_overview_statistics(project_id: project.id)
     )}
  end

  def render(assigns) do
    ~H"""
    <section class="max-w-3xl mx-auto">
      <div class="flex flex-col gap-16">
        <div class="flex flex-col gap-4">
          <.link
            patch={usage_path(@days, @include_api)}
            class="text-sm text-neutral-600 hover:text-urge-600 transition flex items-center gap-1 self-start"
          >
            <Heroicons.arrow_left mini class="h-4 w-4" /> Usage overview
          </.link>
          <div class="flex items-center gap-3">
            <span
              class="h-4 w-4 rounded-full shrink-0"
              style={"background-color: #{@project.color || "#60a5fa"}"}
            >
            </span>
            <h2 class="text-2xl font-medium text-gray-900"><%= @project.name %></h2>
            <span class="chip ~neutral uppercase"><%= @project.code %></span>
            <span :if={not @project.active} class="chip ~critical @high">Archived</span>
          </div>
          <.range_picker days={@days} include_api={@include_api} rest={"/project/#{@project.id}"} />
        </div>

        <.card>
          <:header>
            <p class="sec-head">Overview</p>
            <p class="sec-subhead">
              Activity in this project over the past <%= range_label(@days) %>. Times are UTC.
            </p>
          </:header>
          <dl class="mx-auto grid grid-cols-1 gap-px bg-gray-900/5 sm:grid-cols-3 -m-5">
            <.stat_tile label="Contributions" value={@stats.total_updates} />
            <.stat_tile label="Active members" value={@stats.active_users} />
            <.stat_tile label="Active incidents" value={@stats.active_incidents} />
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
            <div id="usage-project-activity-chart" class="w-full" data-vega={@activity_chart}></div>
          <% end %>
        </.card>

        <.card>
          <:header>
            <p class="sec-head">Incidents by status</p>
            <p class="sec-subhead">All incidents in this project, regardless of time range.</p>
          </:header>
          <%= if Enum.empty?(@status_overview) do %>
            <p class="text-sm text-gray-500">This project has no incidents.</p>
          <% else %>
            <div class="flex flex-wrap gap-2">
              <%= for {status, count} <- Enum.sort_by(@status_overview, &elem(&1, 1), :desc) do %>
                <span class="chip ~neutral flex items-center gap-1.5">
                  <%= status %>
                  <span class="font-semibold tabular-nums">
                    <%= Formatter.format_number(count) %>
                  </span>
                </span>
              <% end %>
            </div>
          <% end %>
        </.card>

        <.card>
          <:header>
            <div class="flex items-center gap-2">
              <span class="flex items-center justify-center h-7 w-7 rounded-md bg-urge-50 text-urge-600">
                <Heroicons.users mini class="h-4 w-4" />
              </span>
              <p class="sec-head">Members</p>
              <span class="chip ~neutral"><%= length(@members) %></span>
            </div>
            <p class="sec-subhead">
              Least recently active first, so the people most likely to need attention surface at the top. Contribution counts include only activity within this project.
            </p>
          </:header>
          <%= if Enum.empty?(@members) do %>
            <p class="text-sm text-gray-500">This project has no members.</p>
          <% else %>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200 text-sm">
                <thead>
                  <tr class="text-left text-xs text-gray-500 uppercase tracking-wide">
                    <th class="py-2 pr-4 font-medium">Member</th>
                    <th class="py-2 pr-4 font-medium">Role</th>
                    <th class="py-2 pr-4 font-medium text-right">Last <%= range_label(@days) %></th>
                    <th class="py-2 pr-4 font-medium text-right">Lifetime</th>
                    <th class="py-2 font-medium text-right">Last active</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  <%= for rollup <- @members do %>
                    <tr>
                      <td class="py-2.5 pr-4">
                        <.link
                          navigate={usage_path(@days, @include_api, "/user/#{rollup.user.username}")}
                          class="flex items-center gap-2 font-medium text-gray-900 hover:text-urge-600 transition"
                        >
                          <img
                            class="h-6 w-6 rounded-full ring-1 ring-neutral-200"
                            src={Platform.Accounts.get_profile_photo_path(rollup.user)}
                            alt={"Profile photo for #{rollup.user.username}"}
                          />
                          <%= rollup.user.username %>
                        </.link>
                      </td>
                      <td class="py-2.5 pr-4">
                        <span class="chip ~neutral"><%= rollup.membership.role %></span>
                      </td>
                      <td class="py-2.5 pr-4 text-right tabular-nums">
                        <span class="flex items-center gap-2 justify-end">
                          <.delta_chip value={rollup.current} prior={rollup.prior} />
                          <%= Formatter.format_number(rollup.current) %>
                        </span>
                      </td>
                      <td class="py-2.5 pr-4 text-right tabular-nums">
                        <%= Formatter.format_number(rollup.lifetime) %>
                      </td>
                      <td class="py-2.5 text-right text-gray-500">
                        <.rel_time time={rollup.last_active_at} />
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </.card>
      </div>
    </section>
    """
  end
end
