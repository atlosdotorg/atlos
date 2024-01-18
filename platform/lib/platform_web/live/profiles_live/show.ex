defmodule PlatformWeb.ProfilesLive.Show do
  use PlatformWeb, :live_view
  alias Platform.Projects
  alias Platform.Accounts
  alias Platform.Updates
  alias PlatformWeb.ProfilesLive.EditComponent

  alias VegaLite, as: Vl

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"username" => username} = _params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:username, username)
     |> assign(:title, username)
     |> assign_user()}
  end

  defp assign_user(socket) do
    with %Accounts.User{} = user <- Accounts.get_user_by_username(socket.assigns.username),
         false <-
           Accounts.is_suspended(user) && !Accounts.is_privileged(socket.assigns.current_user) do
      updates_over_time = Updates.total_updates_by_user_over_time(user)

      activity_indicator_chart =
        Vl.new(height: 150, width: "container")
        |> Vl.data_from_values(
          count: updates_over_time |> Enum.map(fn %{count: count} -> count end),
          date: updates_over_time |> Enum.map(fn %{date: date} -> date end)
        )
        |> Vl.mark(:bar)
        |> Vl.encode_field(:x, "date",
          type: :temporal,
          title: "Time"
        )
        |> Vl.encode_field(:y, "count",
          type: :quantitative,
          title: "Activity"
        )
        |> Vl.encode(:tooltip, [
          [field: "date", type: :temporal, title: "Date"],
          [field: "count", type: :quantitative, title: "Activity"]
        ])
        |> Vl.to_spec()
        |> Jason.encode!()

      socket
      |> assign(:user, user)
      |> assign(
        :updates,
        # We don't show activity for bot accounts
        if(Accounts.is_bot(user), do: [], else: Updates.get_updates_by_user(user, limit: 100))
      )
      |> assign(:most_recent_update, Updates.most_recent_update_by_user(user))
      |> assign(:updates_over_time, updates_over_time)
      |> assign(:activity_indicator_chart, activity_indicator_chart)
      |> then(fn socket ->
        current_user_projects =
          Projects.get_users_project_memberships(socket.assigns.current_user)
          |> Enum.map(fn pm -> pm.project end)
          |> MapSet.new()

        user_projects =
          Projects.get_users_project_memberships(socket.assigns.user)
          |> Enum.map(fn pm -> pm.project end)
          |> MapSet.new()

        socket
        |> assign(
          :shared_projects,
          MapSet.intersection(current_user_projects, user_projects)
        )
      end)
    else
      _ ->
        socket
        |> put_flash(:error, "This user does not exist or is not available.")
        |> redirect(to: "/")
    end
  end
end
