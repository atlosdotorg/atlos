defmodule PlatformWeb.AdminlandLive.UsageComponents do
  @moduledoc """
  Shared UI pieces and Vega-Lite chart builders for the Adminland usage
  dashboard and its drill-down pages.
  """
  use Phoenix.Component

  alias Platform.Accounts
  alias VegaLite, as: Vl

  @valid_days [7, 30, 90, 365]

  # Fixed categorical assignment: each kind of activity always renders in the
  # same color, regardless of which kinds are present in the window.
  @kind_order ["Edits", "Comments", "Uploads", "New incidents", "Other", "API"]
  @kind_colors ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300"]

  def parse_days(%{"days" => days}) do
    case Integer.parse(days) do
      {value, ""} when value in @valid_days -> value
      _ -> 30
    end
  end

  def parse_days(_), do: 30

  def parse_include_api(%{"api" => "0"}), do: false
  def parse_include_api(_), do: true

  def valid_days, do: @valid_days

  def range_label(7), do: "7 days"
  def range_label(30), do: "30 days"
  def range_label(90), do: "90 days"
  def range_label(365), do: "1 year"

  def bucket_for(days) when days <= 30, do: :day
  def bucket_for(_days), do: :week

  def usage_path(days, include_api, rest \\ "", extra \\ %{}) do
    query =
      %{"days" => Integer.to_string(days), "api" => if(include_api, do: "1", else: "0")}
      |> Map.merge(Map.new(extra, fn {k, v} -> {to_string(k), to_string(v)} end))

    "/adminland/usage#{rest}?" <> URI.encode_query(query)
  end

  def palette, do: @kind_colors

  def kind_color(label) do
    case Enum.find_index(@kind_order, &(&1 == label)) do
      nil -> "#94a3b8"
      i -> Enum.at(@kind_colors, i)
    end
  end

  def kind(%{api: true}), do: "API"
  def kind(%{type: :update_attribute}), do: "Edits"
  def kind(%{type: :comment}), do: "Comments"
  def kind(%{type: :upload_version}), do: "Uploads"
  def kind(%{type: :create}), do: "New incidents"
  def kind(_), do: "Other"

  @doc """
  A stacked bar chart of update counts over time, colored by kind of
  activity, as an encoded Vega-Lite spec. Returns `nil` when there is no
  data (render an empty state instead).
  """
  def activity_chart_spec([], _bucket), do: nil

  def activity_chart_spec(rows, bucket) do
    data =
      rows
      |> Enum.group_by(fn row -> {row.date, kind(row)} end)
      |> Enum.map(fn {{date, kind}, group} ->
        %{date: date, kind: kind, count: group |> Enum.map(& &1.count) |> Enum.sum()}
      end)
      |> Enum.sort_by(& &1.date, NaiveDateTime)

    base_chart()
    |> Vl.data_from_values(
      date: Enum.map(data, & &1.date),
      kind: Enum.map(data, & &1.kind),
      count: Enum.map(data, & &1.count)
    )
    |> Vl.mark(:bar, [stroke: "white", stroke_width: 1] ++ bar_mark_opts())
    |> encode_date_axis(bucket)
    |> Vl.encode_field(:y, "count", type: :quantitative, title: "Contributions")
    |> Vl.encode_field(:color, "kind",
      type: :nominal,
      title: nil,
      sort: @kind_order,
      scale: [domain: @kind_order, range: @kind_colors]
    )
    |> Vl.encode(:tooltip, [
      [field: "date", type: :temporal, title: "Date"],
      [field: "kind", type: :nominal, title: "Kind"],
      [field: "count", type: :quantitative, title: "Contributions"]
    ])
    |> Vl.to_spec()
    |> Jason.encode!()
  end

  @doc """
  A single-series bar chart over time as an encoded Vega-Lite spec, or `nil`
  when there is no data.
  """
  def single_series_chart_spec([], _title, _bucket), do: nil

  def single_series_chart_spec(rows, title, bucket) do
    base_chart()
    |> Vl.data_from_values(
      date: Enum.map(rows, & &1.date),
      count: Enum.map(rows, & &1.count)
    )
    |> Vl.mark(:bar, [color: hd(@kind_colors), corner_radius_end: 2] ++ bar_mark_opts())
    |> encode_date_axis(bucket)
    |> Vl.encode_field(:y, "count", type: :quantitative, title: title)
    |> Vl.encode(:tooltip, [
      [field: "date", type: :temporal, title: "Date"],
      [field: "count", type: :quantitative, title: title]
    ])
    |> Vl.to_spec()
    |> Jason.encode!()
  end

  @doc """
  A generic stacked bar chart for the Explore page: rows are
  `%{date, label, color, count}`, with explicit per-label colors so a series
  keeps its hue across queries. Returns `nil` when there is no data.
  """
  def explore_chart_spec([], _bucket), do: nil

  def explore_chart_spec(rows, bucket) do
    labels = rows |> Enum.map(&{&1.label, &1.color}) |> Enum.uniq() |> Enum.sort()

    chart =
      base_chart()
      |> Vl.data_from_values(
        date: Enum.map(rows, & &1.date),
        label: Enum.map(rows, & &1.label),
        count: Enum.map(rows, & &1.count)
      )
      |> Vl.mark(:bar, [stroke: "white", stroke_width: 1] ++ bar_mark_opts())
      |> encode_date_axis(bucket)
      |> Vl.encode_field(:y, "count", type: :quantitative, title: "Count")
      |> Vl.encode_field(:color, "label",
        type: :nominal,
        title: nil,
        # The page renders its own clickable legend chips, so the drill
        # affordance sits right on the chart instead of Vega's static legend.
        legend: nil,
        scale: [
          domain: Enum.map(labels, &elem(&1, 0)),
          range: Enum.map(labels, &elem(&1, 1))
        ]
      )
      |> Vl.encode(:tooltip, [
        [field: "date", type: :temporal, title: "Date"],
        [field: "label", type: :nominal, title: "Series"],
        [field: "count", type: :quantitative, title: "Count"]
      ])

    chart |> Vl.to_spec() |> Jason.encode!()
  end

  defp base_chart do
    Vl.new(height: 220, width: "container", background: "transparent")
    |> Vl.config(
      view: [stroke: nil],
      axis: [
        grid_color: "#f1f5f9",
        domain_color: "#e2e8f0",
        tick_color: "#e2e8f0",
        label_color: "#64748b",
        title_color: "#94a3b8",
        label_font_size: 11,
        title_font_size: 11,
        title_padding: 10
      ],
      legend: [
        orient: "top",
        label_color: "#475569",
        symbol_type: "circle",
        symbol_size: 80,
        padding: 0
      ]
    )
  end

  # A fixed tick count and day-level label format keep the axis legible: with
  # sparse data, Vega-Lite otherwise falls back to hour-level tick labels.
  # The time_unit gives bars a band to fill (see bar_mark_opts/0); without it
  # a continuous temporal scale renders skinny sliver bars.
  defp encode_date_axis(chart, bucket) do
    time_unit =
      case bucket do
        :day -> "yearmonthdate"
        :week -> "yearweek"
        :month -> "yearmonth"
      end

    Vl.encode_field(chart, :x, "date",
      type: :temporal,
      time_unit: time_unit,
      title: nil,
      axis: [format: "%b %d", tick_count: 6, label_angle: 0]
    )
  end

  defp bar_mark_opts, do: [width: [band: 0.8]]

  attr(:label, :string, required: true)
  attr(:value, :integer, required: true)
  attr(:prior, :integer, default: nil)

  def stat_tile(assigns) do
    ~H"""
    <div class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-2 bg-white px-4 py-8 sm:px-6">
      <dt class="text-sm font-medium leading-6 text-gray-500"><%= @label %></dt>
      <dd class="w-full flex-none text-3xl font-medium leading-10 tracking-tight text-gray-900">
        <%= Formatter.format_number(@value) %>
      </dd>
      <dd :if={not is_nil(@prior)} class="text-xs text-gray-500 flex items-center gap-2">
        <.delta_chip value={@value} prior={@prior} />
        <span>vs. <%= Formatter.format_number(@prior) %> prior</span>
      </dd>
    </div>
    """
  end

  attr(:value, :integer, required: true)
  attr(:prior, :integer, required: true)

  def delta_chip(assigns) do
    ~H"""
    <%= cond do %>
      <% @prior > 0 and @value > @prior -> %>
        <span class="chip ~positive @high">
          &uarr; <%= round((@value - @prior) / @prior * 100) %>%
        </span>
      <% @prior > 0 and @value < @prior -> %>
        <span class="chip ~critical @high">
          &darr; <%= round((@prior - @value) / @prior * 100) %>%
        </span>
      <% @prior == 0 and @value > 0 -> %>
        <span class="chip ~positive @high">New</span>
      <% true -> %>
        <span class="chip ~neutral">&mdash;</span>
    <% end %>
    """
  end

  attr(:user, :map, required: true)
  attr(:navigate, :string, required: true)
  slot(:detail, required: true)

  def person_row(assigns) do
    ~H"""
    <li class="flex items-center justify-between gap-4 py-3">
      <.link navigate={@navigate} class="flex items-center gap-3 min-w-0 group">
        <img
          class="h-8 w-8 rounded-full shrink-0 ring-1 ring-neutral-200"
          src={Accounts.get_profile_photo_path(@user)}
          alt={"Profile photo for #{@user.username}"}
        />
        <span class="font-medium text-sm text-gray-900 truncate group-hover:text-urge-600 transition">
          <%= @user.username %>
        </span>
        <span :if={:muted in (@user.restrictions || [])} class="chip ~warning @high">Muted</span>
        <span :if={:suspended in (@user.restrictions || [])} class="chip ~critical @high">
          Suspended
        </span>
      </.link>
      <span class="text-xs text-gray-500 text-right shrink-0">
        <%= render_slot(@detail) %>
      </span>
    </li>
    """
  end

  attr(:share, :float, required: true)

  def share_meter(assigns) do
    ~H"""
    <span class="flex items-center gap-2 justify-end">
      <span class="w-16 bg-neutral-100 rounded-full h-1.5 overflow-hidden">
        <span
          class={"block h-1.5 rounded-full " <>
            if(@share > 0.5, do: "bg-warning-500", else: "bg-urge-400")}
          style={"width: #{round(@share * 100)}%"}
        >
        </span>
      </span>
      <span class="tabular-nums"><%= round(@share * 100) %>%</span>
    </span>
    """
  end

  attr(:days, :integer, required: true)
  attr(:include_api, :boolean, required: true)
  attr(:rest, :string, default: "")
  attr(:extra_params, :map, default: %{})
  slot(:extra)

  def range_picker(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <div
        class="flex items-center gap-1 bg-neutral-100 rounded-lg p-1 self-start"
        role="group"
        aria-label="Time range"
      >
        <%= for days <- valid_days() do %>
          <.link
            patch={usage_path(days, @include_api, @rest, @extra_params)}
            class={
              if(days == @days,
                do:
                  "rounded-md transition bg-white shadow-sm text-urge-600 px-3 py-1 font-medium text-sm",
                else:
                  "rounded-md transition text-neutral-600 hover:text-neutral-900 px-3 py-1 font-medium text-sm"
              )
            }
          >
            <%= range_label(days) %>
          </.link>
        <% end %>
      </div>
      <div class="flex items-center gap-5 flex-wrap">
        <.link
          patch={usage_path(@days, not @include_api, @rest, @extra_params)}
          class="text-sm text-neutral-600 hover:text-neutral-700 flex items-center gap-2"
        >
          <%= if @include_api do %>
            <Heroicons.check_circle mini class="h-4 w-4 text-urge-600" />
          <% else %>
            <Heroicons.minus_circle mini class="h-4 w-4 opacity-50" />
          <% end %>
          Include API activity
        </.link>
        <%= render_slot(@extra) %>
      </div>
    </div>
    """
  end
end
