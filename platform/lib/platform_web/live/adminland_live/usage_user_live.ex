defmodule PlatformWeb.AdminlandLive.UsageUserLive do
  @moduledoc """
  Person drill-down for the Adminland usage dashboard. The header separates
  "last signed in" from "last contributed": the gap between the two
  distinguishes someone who is gone from someone who signs in but is stuck,
  which call for different kinds of outreach.
  """
  use PlatformWeb, :live_component

  import Ecto.Query, warn: false
  import PlatformWeb.AdminlandLive.UsageComponents

  alias Platform.Accounts
  alias Platform.Repo
  alias Platform.Statistics
  alias Platform.Updates
  alias PlatformWeb.AdminlandLive.UsageComponents

  def update(assigns, socket) do
    days = parse_days(assigns[:params])
    include_api = parse_include_api(assigns[:params])
    bucket = bucket_for(days)

    user =
      case Accounts.get_user_by_username(assigns.params["username"]) do
        nil -> raise Ecto.NoResultsError, queryable: Platform.Accounts.User
        user -> Repo.preload(user, invite_uses: [invite: :owner])
      end

    activity = Statistics.activity_over_time(days: days, bucket: bucket, user_id: user.id)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:days, days)
     |> assign(:include_api, include_api)
     |> assign(:user, user)
     |> assign(:last_session_at, Statistics.last_session_at(user.id))
     |> assign(:activity_chart, UsageComponents.activity_chart_spec(activity, bucket))
     |> assign(:project_rollups, Statistics.user_project_rollups(user.id, days: days))
     |> assign(:recent_updates, Updates.get_updates_by_user(user, limit: 15))
     |> assign(
       :api_tokens,
       Repo.all(
         from(t in Platform.API.APIToken,
           where: t.creator_id == ^user.id,
           order_by: [desc: t.inserted_at]
         )
       )
     )}
  end

  defp last_contributed_at(project_rollups) do
    project_rollups
    |> Enum.map(& &1.last_active_at)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      dates -> Enum.max(dates, NaiveDateTime)
    end
  end

  def render(assigns) do
    assigns = assign(assigns, :last_contributed_at, last_contributed_at(assigns.project_rollups))

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
          <div class="flex items-center gap-4">
            <img
              class="h-14 w-14 rounded-full ring-2 ring-white shadow"
              src={Accounts.get_profile_photo_path(@user)}
              alt={"Profile photo for #{@user.username}"}
            />
            <div class="flex flex-col gap-1">
              <div class="flex items-center gap-2">
                <h2 class="text-2xl font-medium text-gray-900"><%= @user.username %></h2>
                <span :if={:admin in (@user.roles || [])} class="chip ~urge @high">Admin</span>
                <span :if={:muted in (@user.restrictions || [])} class="chip ~warning @high">
                  Muted
                </span>
                <span :if={:suspended in (@user.restrictions || [])} class="chip ~critical @high">
                  Suspended
                </span>
              </div>
              <p class="text-sm text-gray-500 flex items-center gap-3 flex-wrap">
                <span>Joined <.rel_time time={@user.inserted_at} /></span>
                <%= for use <- @user.invite_uses do %>
                  <span :if={not is_nil(use.invite)}>
                    &middot; Invited by
                    <%= if is_nil(use.invite.owner) do %>
                      code <code class="text-xs"><%= use.invite.code %></code>
                    <% else %>
                      <.link
                        navigate={"/profile/" <> use.invite.owner.username}
                        class="text-urge-600 hover:text-urge-700 font-medium"
                      >
                        <%= use.invite.owner.username %>
                      </.link>
                    <% end %>
                  </span>
                <% end %>
                <span>
                  &middot;
                  <.link
                    navigate={"/profile/" <> @user.username}
                    class="text-urge-600 hover:text-urge-700 font-medium"
                  >
                    View profile
                  </.link>
                </span>
              </p>
            </div>
          </div>
          <.range_picker days={@days} include_api={@include_api} rest={"/user/#{@user.username}"} />
        </div>

        <.card>
          <:header>
            <p class="sec-head">Engagement</p>
            <p class="sec-subhead">
              Someone who signs in but does not contribute may be stuck rather than gone. Times are UTC.
            </p>
          </:header>
          <dl class="mx-auto grid grid-cols-1 gap-px bg-gray-900/5 sm:grid-cols-2 -m-5">
            <div class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-2 bg-white px-4 py-8 sm:px-6">
              <dt class="text-sm font-medium leading-6 text-gray-500">Last signed in</dt>
              <dd class="w-full flex-none text-xl font-medium leading-10 tracking-tight text-gray-900">
                <.rel_time time={@last_session_at} />
              </dd>
            </div>
            <div class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-2 bg-white px-4 py-8 sm:px-6">
              <dt class="text-sm font-medium leading-6 text-gray-500">Last contributed</dt>
              <dd class="w-full flex-none text-xl font-medium leading-10 tracking-tight text-gray-900">
                <.rel_time time={@last_contributed_at} />
              </dd>
            </div>
          </dl>
        </.card>

        <.card>
          <:header>
            <p class="sec-head">Activity over time</p>
            <p class="sec-subhead">
              Their contributions per <%= if bucket_for(@days) == :day, do: "day", else: "week" %>, by kind of activity.
            </p>
          </:header>
          <%= if is_nil(@activity_chart) do %>
            <p class="text-sm text-gray-500">No activity in this window.</p>
          <% else %>
            <div id="usage-user-activity-chart" class="w-full" data-vega={@activity_chart}></div>
          <% end %>
        </.card>

        <.card>
          <:header>
            <div class="flex items-center gap-2">
              <span class="flex items-center justify-center h-7 w-7 rounded-md bg-urge-50 text-urge-600">
                <Heroicons.squares_2x2 mini class="h-4 w-4" />
              </span>
              <p class="sec-head">Projects</p>
              <span class="chip ~neutral"><%= length(@project_rollups) %></span>
            </div>
            <p class="sec-subhead">
              Their memberships, with their own contributions in each project.
            </p>
          </:header>
          <%= if Enum.empty?(@project_rollups) do %>
            <p class="text-sm text-gray-500">They are not a member of any project.</p>
          <% else %>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200 text-sm">
                <thead>
                  <tr class="text-left text-xs text-gray-500 uppercase tracking-wide">
                    <th class="py-2 pr-4 font-medium">Project</th>
                    <th class="py-2 pr-4 font-medium">Role</th>
                    <th class="py-2 pr-4 font-medium text-right">Last <%= range_label(@days) %></th>
                    <th class="py-2 pr-4 font-medium text-right">Lifetime</th>
                    <th class="py-2 font-medium text-right">Last active</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  <%= for rollup <- @project_rollups do %>
                    <tr>
                      <td class="py-2.5 pr-4">
                        <.link
                          navigate={usage_path(@days, @include_api, "/project/#{rollup.project.id}")}
                          class="flex items-center gap-2 font-medium text-gray-900 hover:text-urge-600 transition"
                        >
                          <span
                            class="h-2.5 w-2.5 rounded-full shrink-0"
                            style={"background-color: #{rollup.project.color || "#60a5fa"}"}
                          >
                          </span>
                          <%= rollup.project.name %>
                        </.link>
                      </td>
                      <td class="py-2.5 pr-4">
                        <span class="chip ~neutral"><%= rollup.membership.role %></span>
                      </td>
                      <td class="py-2.5 pr-4 text-right tabular-nums">
                        <%= Formatter.format_number(rollup.current) %>
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

        <.card :if={not Enum.empty?(@api_tokens)}>
          <:header>
            <div class="flex items-center gap-2">
              <span class="flex items-center justify-center h-7 w-7 rounded-md bg-urge-50 text-urge-600">
                <Heroicons.key mini class="h-4 w-4" />
              </span>
              <p class="sec-head">API tokens</p>
            </div>
            <p class="sec-subhead">Tokens this person created.</p>
          </:header>
          <ul class="divide-y divide-gray-100 text-sm">
            <%= for token <- @api_tokens do %>
              <li class="flex items-center justify-between gap-4 py-2.5">
                <span class="flex items-center gap-2 font-medium text-gray-900">
                  <%= token.name %>
                  <span :if={not token.is_active} class="chip ~critical @high">Inactive</span>
                  <span :if={token.is_legacy} class="chip ~warning">Legacy</span>
                </span>
                <span class="text-xs text-gray-500">
                  <%= if is_nil(token.last_used) do %>
                    Never used
                  <% else %>
                    Last used <%= Calendar.strftime(token.last_used, "%d %b %Y") %>
                  <% end %>
                </span>
              </li>
            <% end %>
          </ul>
        </.card>

        <.card>
          <:header>
            <p class="sec-head">Recent activity</p>
            <p class="sec-subhead">Their latest contributions, across all projects.</p>
          </:header>
          <%= if Enum.empty?(@recent_updates) do %>
            <p class="text-sm text-gray-500">They have no recorded activity.</p>
          <% else %>
            <.live_component
              module={PlatformWeb.UpdatesLive.UpdateFeed}
              updates={@recent_updates}
              current_user={@current_user}
              reverse={true}
              show_media={true}
              show_final_line={false}
              ignore_permissions={true}
              id="usage-user-updates-feed"
            />
          <% end %>
        </.card>
      </div>
    </section>
    """
  end
end
