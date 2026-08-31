defmodule PlatformWeb.AdminlandLive.UsageExploreLive do
  @moduledoc """
  Freeform analysis inside the Adminland usage dashboard: compose a question
  as a sentence — show [metric] by [dimension] over the last [window] — and
  drill in by clicking breakdown rows, which add filters and advance the
  split one level deeper. All state lives in the URL, so any view is a
  shareable link.
  """
  use PlatformWeb, :live_component

  import Ecto.Query, warn: false
  import PlatformWeb.AdminlandLive.UsageComponents

  alias Platform.Accounts
  alias Platform.Projects.Project
  alias Platform.Repo
  alias Platform.Statistics
  alias PlatformWeb.AdminlandLive.UsageComponents

  @metrics [
    {"contributions", "contributions"},
    {"incidents", "incidents created"},
    {"active", "active people"},
    {"signups", "new sign-ups"}
  ]
  @splits [
    {"none", "— total —"},
    {"kind", "kind of activity"},
    {"project", "project"},
    {"person", "person"},
    {"source", "source (human / API)"}
  ]
  @kinds ~w(update_attribute comment upload_version create delete undelete add_project change_project remove_project)

  def update(assigns, socket) do
    state = parse_state(assigns[:params])
    {series, totals} = load_data(state)
    labels = build_labels(state, series, totals)

    table_rows =
      totals
      |> Enum.map(fn row ->
        {label, color} = labels[label_key(state.split, row)] || {"Unknown", "#94a3b8"}
        Map.merge(row, %{label: label, color: color, drill: drill_params(state, row, label)})
      end)

    total = table_rows |> Enum.map(& &1.current) |> Enum.sum()
    prior_total = table_rows |> Enum.map(& &1.prior) |> Enum.sum()

    # The chart folds everything beyond the top series into "Other" so the
    # legend stays legible; the breakdown table below still lists everyone.
    top_labels = table_rows |> Enum.take(7) |> MapSet.new(& &1.label)

    chart_rows =
      series
      |> Enum.map(fn row ->
        {label, color} = labels[label_key(state.split, row)] || {"Unknown", "#94a3b8"}

        if MapSet.member?(top_labels, label),
          do: %{date: row.date, label: label, color: color, count: row.count},
          else: %{date: row.date, label: "Other", color: "#94a3b8", count: row.count}
      end)
      |> Enum.group_by(&{&1.date, &1.label})
      |> Enum.map(fn {_key, rows} ->
        %{hd(rows) | count: rows |> Enum.map(& &1.count) |> Enum.sum()}
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:state, state)
     |> assign(:metrics, @metrics)
     |> assign(:splits, @splits)
     |> assign(
       :chart,
       UsageComponents.explore_chart_spec(chart_rows, bucket_for(state.days))
     )
     |> assign(:table_rows, table_rows)
     |> assign(:legend_rows, Enum.take(table_rows, 7))
     |> assign(:legend_other, length(table_rows) > 7)
     |> assign(:total, total)
     |> assign(:prior_total, prior_total)
     |> assign(:filter_chips, filter_chips(state))}
  end

  def handle_event("change", params, socket) do
    state = socket.assigns.state

    next = %{
      state
      | metric: parse_metric(params["metric"]),
        split: parse_split(params["split"]),
        days: UsageComponents.parse_days(params)
    }

    {:noreply, push_patch(socket, to: explore_path(next))}
  end

  # ---- State ----

  defp parse_state(params) do
    params = params || %{}

    %{
      metric: parse_metric(params["metric"]),
      split: parse_split(params["split"]),
      days: UsageComponents.parse_days(params),
      filters: parse_filters(params)
    }
    |> then(fn state ->
      if state.metric == :signups, do: %{state | split: :none, filters: %{}}, else: state
    end)
  end

  defp parse_metric(m) when m in ~w(contributions incidents active signups),
    do: String.to_existing_atom(m)

  defp parse_metric(_), do: :contributions

  defp parse_split(s) when s in ~w(none kind project person source),
    do: String.to_existing_atom(s)

  defp parse_split(_), do: :kind

  defp parse_filters(params) do
    %{}
    |> then(fn f ->
      case params["f_project"] do
        id when is_binary(id) and id != "" ->
          case Ecto.UUID.cast(id) do
            {:ok, _} -> Map.put(f, :project, id)
            :error -> f
          end

        _ ->
          f
      end
    end)
    |> then(fn f ->
      case params["f_user"] do
        u when is_binary(u) and u != "" -> Map.put(f, :user, u)
        _ -> f
      end
    end)
    |> then(fn f ->
      case params["f_kind"] do
        k when k in @kinds -> Map.put(f, :kind, String.to_existing_atom(k))
        _ -> f
      end
    end)
    |> then(fn f ->
      case params["f_source"] do
        s when s in ~w(api human) -> Map.put(f, :source, String.to_existing_atom(s))
        _ -> f
      end
    end)
  end

  defp explore_path(state) do
    query =
      [
        {"metric", state.metric != :contributions && Atom.to_string(state.metric)},
        {"split", state.split != :kind && Atom.to_string(state.split)},
        {"days", state.days != 30 && Integer.to_string(state.days)},
        {"f_project", state.filters[:project]},
        {"f_user", state.filters[:user]},
        {"f_kind", state.filters[:kind] && Atom.to_string(state.filters[:kind])},
        {"f_source", state.filters[:source] && Atom.to_string(state.filters[:source])}
      ]
      |> Enum.filter(fn {_k, v} -> v not in [nil, false] end)

    "/adminland/usage/explore" <>
      if(Enum.empty?(query), do: "", else: "?" <> URI.encode_query(query))
  end

  # ---- Data ----

  defp load_data(%{metric: :signups, days: days}) do
    series =
      Statistics.new_users_over_time(days: days, bucket: bucket_for(days))
      |> Enum.map(&Map.put(&1, :signups, true))

    stats = Statistics.new_user_statistics(days: days)
    {series, [%{signups: true, current: stats.current, prior: stats.prior}]}
  end

  defp load_data(state) do
    opts =
      [
        metric: state.metric,
        split: state.split,
        days: state.days,
        filter_project_id: state.filters[:project],
        filter_user_id: state.filters[:user] && user_id_for(state.filters[:user]),
        filter_kind: state.filters[:kind],
        filter_source: state.filters[:source]
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    {Statistics.explore_series(opts ++ [bucket: bucket_for(state.days)]),
     Statistics.explore_totals(opts)}
  end

  defp user_id_for(username) do
    case Accounts.get_user_by_username(username) do
      nil -> Ecto.UUID.generate()
      user -> user.id
    end
  end

  # ---- Labels & colors ----

  defp label_key(_split, %{signups: true}), do: :signups
  defp label_key(:none, _row), do: :total
  defp label_key(:kind, row), do: {row.type, row.api}
  defp label_key(:project, row), do: row.project_id
  defp label_key(:person, row), do: row.user_id
  defp label_key(:source, row), do: row.api

  defp build_labels(%{metric: :signups}, _series, _totals),
    do: %{signups: {"New sign-ups", "#2a78d6"}}

  defp build_labels(%{split: :none, metric: metric}, _series, _totals) do
    label = @metrics |> Enum.find(&(elem(&1, 0) == Atom.to_string(metric))) |> elem(1)
    %{total: {String.capitalize(label), "#2a78d6"}}
  end

  defp build_labels(%{split: :kind}, series, totals) do
    (series ++ totals)
    |> Enum.map(&label_key(:kind, &1))
    |> Enum.uniq()
    |> Map.new(fn {type, api} = key ->
      label = UsageComponents.kind(%{type: type, api: api})
      {key, {label, UsageComponents.kind_color(label)}}
    end)
  end

  defp build_labels(%{split: :source}, _series, _totals) do
    %{false: {"Human", "#2a78d6"}, true: {"API", "#008300"}}
  end

  defp build_labels(%{split: :project}, series, totals) do
    ids = (series ++ totals) |> Enum.map(& &1.project_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    projects =
      from(p in Project, where: p.id in ^ids)
      |> Repo.all()
      |> Map.new(&{&1.id, {&1.name, &1.color || "#60a5fa"}})

    Map.put(projects, nil, {"No project", "#94a3b8"})
  end

  defp build_labels(%{split: :person}, series, totals) do
    ids = (series ++ totals) |> Enum.map(& &1.user_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    users =
      from(u in Accounts.User, where: u.id in ^ids, select: {u.id, u.username})
      |> Repo.all()
      |> Enum.sort_by(&elem(&1, 1))

    palette = UsageComponents.palette()

    users
    |> Enum.with_index()
    |> Map.new(fn {{id, username}, i} ->
      {id, {username, Enum.at(palette, rem(i, length(palette)))}}
    end)
    |> Map.put(nil, {"API", "#008300"})
  end

  # ---- Drilling ----

  # Clicking a breakdown row filters to that value and advances the split one
  # level deeper. Returns the next state, or nil when there is nowhere to go.
  defp drill_params(%{split: :none}, _row, _label), do: nil
  defp drill_params(_state, %{signups: true}, _label), do: nil

  defp drill_params(state, row, label) do
    case {state.split, row} do
      {:kind, %{api: true}} ->
        %{state | split: :project, filters: Map.put(state.filters, :source, :api)}

      {:kind, %{type: type}} ->
        %{state | split: :project, filters: Map.put(state.filters, :kind, type)}

      {:project, %{project_id: nil}} ->
        nil

      {:project, %{project_id: id}} ->
        %{state | split: :person, filters: Map.put(state.filters, :project, id)}

      {:person, %{user_id: nil}} ->
        %{state | split: :project, filters: Map.put(state.filters, :source, :api)}

      {:person, %{user_id: _id}} ->
        %{state | split: :kind, filters: Map.put(state.filters, :user, label)}

      {:source, %{api: api}} ->
        %{
          state
          | split: :kind,
            filters: Map.put(state.filters, :source, if(api, do: :api, else: :human))
        }

      _ ->
        nil
    end
  end

  defp filter_chips(state) do
    Enum.map(state.filters, fn {dim, value} ->
      label =
        case {dim, value} do
          {:project, id} ->
            name = Repo.one(from(p in Project, where: p.id == ^id, select: p.name))
            "project: #{name || "unknown"}"

          {:user, username} ->
            "person: #{username}"

          {:kind, kind} ->
            "kind: #{UsageComponents.kind(%{type: kind, api: false})}"

          {:source, source} ->
            "source: #{if source == :api, do: "API", else: "human"}"
        end

      without = %{state | filters: Map.delete(state.filters, dim)}
      {label, explore_path(without)}
    end)
  end

  defp preset(state, overrides), do: explore_path(Map.merge(state, overrides))

  def render(assigns) do
    ~H"""
    <section class="max-w-3xl mx-auto">
      <div class="flex flex-col gap-8">
        <div class="flex flex-col gap-4">
          <.link
            patch={usage_path(@state.days, true)}
            class="text-sm text-neutral-600 hover:text-urge-600 transition flex items-center gap-1 self-start"
          >
            <Heroicons.arrow_left mini class="h-4 w-4" /> Usage overview
          </.link>
          <div class="flex items-center gap-2 flex-wrap text-sm text-neutral-500">
            <span class="uppercase text-xs font-medium tracking-wide">Quick views</span>
            <.link
              patch={
                preset(@state, %{metric: :contributions, split: :project, filters: %{kind: :comment}})
              }
              class="chip ~neutral hover:text-urge-600 transition"
            >
              Comments by project
            </.link>
            <.link
              patch={preset(@state, %{metric: :contributions, split: :source, filters: %{}})}
              class="chip ~neutral hover:text-urge-600 transition"
            >
              API vs. human
            </.link>
            <.link
              patch={preset(@state, %{metric: :active, split: :project, filters: %{}})}
              class="chip ~neutral hover:text-urge-600 transition"
            >
              Active people by project
            </.link>
            <.link
              patch={preset(@state, %{metric: :signups, split: :none, filters: %{}})}
              class="chip ~neutral hover:text-urge-600 transition"
            >
              Sign-ups
            </.link>
          </div>
        </div>

        <.card>
          <form phx-change="change" phx-target={@myself} class="ts-ignore">
            <div class="flex flex-wrap items-center gap-2 text-sm">
              <span class="text-neutral-500">Show</span>
              <select
                name="metric"
                class="rounded-full border-gray-300 bg-neutral-100 text-sm font-medium py-1 pl-3 pr-8 focus:ring-urge-500 focus:border-urge-500"
              >
                <%= for {value, label} <- @metrics do %>
                  <option value={value} selected={value == Atom.to_string(@state.metric)}>
                    <%= label %>
                  </option>
                <% end %>
              </select>
              <span class="text-neutral-500">by</span>
              <select
                name="split"
                disabled={@state.metric == :signups}
                class="rounded-full border-gray-300 bg-neutral-100 text-sm font-medium py-1 pl-3 pr-8 focus:ring-urge-500 focus:border-urge-500 disabled:opacity-50"
              >
                <%= for {value, label} <- @splits do %>
                  <option value={value} selected={value == Atom.to_string(@state.split)}>
                    <%= label %>
                  </option>
                <% end %>
              </select>
              <span class="text-neutral-500">over the last</span>
              <select
                name="days"
                class="rounded-full border-gray-300 bg-neutral-100 text-sm font-medium py-1 pl-3 pr-8 focus:ring-urge-500 focus:border-urge-500"
              >
                <%= for days <- valid_days() do %>
                  <option value={days} selected={days == @state.days}>
                    <%= range_label(days) %>
                  </option>
                <% end %>
              </select>
            </div>
          </form>
          <div class="flex flex-wrap items-center gap-2 mt-3">
            <%= for {label, remove_path} <- @filter_chips do %>
              <span class="chip ~urge flex items-center gap-1">
                <%= label %>
                <.link
                  patch={remove_path}
                  aria-label={"Remove filter " <> label}
                  class="hover:opacity-70"
                >
                  &times;
                </.link>
              </span>
            <% end %>
            <span :if={Enum.empty?(@filter_chips)} class="text-xs text-neutral-400">
              No filters — click a series or breakdown row to drill in.
            </span>
          </div>
        </.card>

        <.card>
          <:header>
            <div class="flex items-baseline gap-3 flex-wrap">
              <p class="sec-head">Result</p>
              <span class="text-2xl font-medium tabular-nums text-gray-900">
                <%= Formatter.format_number(@total) %>
              </span>
              <.delta_chip value={@total} prior={@prior_total} />
              <span class="text-xs text-neutral-400">vs. prior <%= range_label(@state.days) %></span>
            </div>
          </:header>
          <div
            :if={length(@legend_rows) > 1 or @legend_other}
            class="flex flex-wrap items-center gap-1.5 mb-3"
          >
            <%= for row <- @legend_rows do %>
              <%= if is_nil(row.drill) do %>
                <span class="inline-flex items-center gap-1.5 rounded-full border border-gray-200 px-2.5 py-0.5 text-xs font-medium text-gray-700">
                  <span class="h-2 w-2 rounded-full shrink-0" style={"background-color: #{row.color}"}>
                  </span>
                  <%= row.label %>
                </span>
              <% else %>
                <.link
                  patch={explore_path(row.drill)}
                  title={"Filter to #{row.label} and split one level deeper"}
                  class="inline-flex items-center gap-1.5 rounded-full border border-gray-200 px-2.5 py-0.5 text-xs font-medium text-gray-700 hover:border-urge-500 hover:text-urge-600 transition"
                >
                  <span class="h-2 w-2 rounded-full shrink-0" style={"background-color: #{row.color}"}>
                  </span>
                  <%= row.label %>
                </.link>
              <% end %>
            <% end %>
            <span
              :if={@legend_other}
              class="inline-flex items-center gap-1.5 rounded-full border border-gray-200 px-2.5 py-0.5 text-xs font-medium text-gray-500"
            >
              <span class="h-2 w-2 rounded-full shrink-0" style="background-color: #94a3b8"></span>
              Other
            </span>
            <span :if={@state.split != :none} class="text-xs text-neutral-400 ml-1">
              Click a series to drill in.
            </span>
          </div>
          <%= if is_nil(@chart) do %>
            <p class="text-sm text-gray-500">Nothing matches this query in this window.</p>
          <% else %>
            <div id="usage-explore-chart" class="w-full" data-vega={@chart}></div>
          <% end %>
          <div :if={not Enum.empty?(@table_rows)} class="mt-6 border-t border-gray-100 pt-4">
            <p class="text-xs text-gray-500 uppercase tracking-wide font-medium mb-1">Breakdown</p>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200 text-sm">
                <thead>
                  <tr class="text-left text-xs text-gray-500 uppercase tracking-wide">
                    <th class="py-2 pr-4 font-medium">Series</th>
                    <th class="py-2 pr-4 font-medium text-right">Count</th>
                    <th class="py-2 pr-4 font-medium text-right">Share</th>
                    <th class="py-2 font-medium text-right">vs. prior</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  <%= for row <- Enum.take(@table_rows, 15) do %>
                    <tr>
                      <td class="py-2.5 pr-4">
                        <%= if is_nil(row.drill) do %>
                          <span class="flex items-center gap-2 font-medium text-gray-900">
                            <span
                              class="h-2.5 w-2.5 rounded-full shrink-0"
                              style={"background-color: #{row.color}"}
                            >
                            </span>
                            <%= row.label %>
                          </span>
                        <% else %>
                          <.link
                            patch={explore_path(row.drill)}
                            class="flex items-center gap-2 font-medium text-gray-900 hover:text-urge-600 transition"
                          >
                            <span
                              class="h-2.5 w-2.5 rounded-full shrink-0"
                              style={"background-color: #{row.color}"}
                            >
                            </span>
                            <%= row.label %>
                          </.link>
                        <% end %>
                      </td>
                      <td class="py-2.5 pr-4 text-right tabular-nums">
                        <%= Formatter.format_number(row.current) %>
                      </td>
                      <td class="py-2.5 pr-4 text-right tabular-nums">
                        <%= if @total > 0 do %>
                          <.share_meter share={row.current / @total} />
                        <% else %>
                          &mdash;
                        <% end %>
                      </td>
                      <td class="py-2.5 text-right">
                        <.delta_chip value={row.current} prior={row.prior} />
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
              <p :if={length(@table_rows) > 15} class="text-xs text-gray-500 mt-2">
                And <%= length(@table_rows) - 15 %> more.
              </p>
            </div>
          </div>
        </.card>
      </div>
    </section>
    """
  end
end
