defmodule PlatformWeb.SPIController do
  use PlatformWeb, :controller
  require Ecto.Query

  alias Platform.Projects
  alias Platform.Permissions

  def user_search(conn, params) do
    query = Map.get(params, "query", "") |> String.downcase()

    project_id =
      case Map.get(params, "project_id") do
        "" -> nil
        nil -> nil
        "null" -> nil
        project_id -> project_id
      end

    get_project_users = fn project ->
      if is_nil(project) or
           not Permissions.can_view_project?(conn.assigns.current_user, project) do
        raise PlatformWeb.Errors.NotFound, "Project not found"
      end

      Projects.get_project_users(project)
    end

    # If the project is present, we get the users for the project. Otherwise, we get the users for all the projects the user is a member of.
    users =
      if is_nil(project_id) do
        projects = Projects.list_projects_for_user(conn.assigns.current_user)

        Enum.map(projects, get_project_users)
        |> List.flatten()
      else
        project = Projects.get_project!(project_id)
        get_project_users.(project)
      end

    json(conn, %{
      results:
        users
        |> Enum.filter(&String.starts_with?(&1.username |> String.downcase(), query))
        |> Enum.uniq_by(& &1.username)
        |> Enum.take(5)
        |> Enum.map(&%{username: &1.username, bio: &1.bio, flair: &1.flair})
    })
  end
end
