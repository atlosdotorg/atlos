defmodule PlatformWeb.MCP.Tools.ListProjects do
  @behaviour PlatformWeb.MCP.Tool

  alias Platform.API.APIToken
  alias Platform.Accounts.User
  alias Platform.Projects
  alias PlatformWeb.MCP.Context

  @impl true
  def name, do: "list_projects"

  @impl true
  def description do
    "List the Atlos projects this connection can access, with your role in each and what " <>
      "you can do there (read, comment, edit). Pass a project's `id` or `code` as the " <>
      "`project` argument of other tools. Call `get_project` for a project's attributes."
  end

  @impl true
  def input_schema do
    %{
      "type" => "object",
      "properties" => %{},
      "additionalProperties" => false
    }
  end

  @impl true
  def required_permission, do: :read

  @impl true
  def read_only?, do: true

  @impl true
  def call(%Context{actor: %APIToken{}} = context, _args) do
    project = Projects.get_project!(context.project_id)
    {:ok, %{projects: [summary(project, nil, context.permissions)]}}
  end

  def call(%Context{actor: %User{}} = context, _args) do
    projects =
      Context.memberships(context)
      |> Enum.map(fn membership ->
        summary(
          membership.project,
          membership.role,
          Context.permissions_in_project(context, membership.project_id)
        )
      end)

    {:ok, %{projects: projects}}
  end

  defp summary(project, role, permissions) do
    %{
      id: project.id,
      name: project.name,
      code: project.code,
      description: project.description,
      active: project.active,
      role: role,
      permissions: permissions
    }
  end
end
