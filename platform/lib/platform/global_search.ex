defmodule Platform.GlobalSearch do
  @moduledoc """
  Global search functionality.
  """

  import Ecto.Query, warn: false
  alias Platform.Projects.Project
  alias Platform.Material.Media
  alias Platform.Material.MediaVersion
  alias Platform.Updates.Update
  alias Platform.Accounts.User
  alias Platform.Repo

  alias Platform.Permissions

  use Memoize

  @doc """
  Search all of Atlos for a given query string for the user.
  """
  defmemo perform_search(query, %User{} = user) when is_binary(query), expires_in: 10000 do
    query =
      String.trim(query)
      |> String.downcase()
      |> String.replace(~r/\s+/, "|")
      |> String.replace("\\", "")
      |> String.trim()

    query_only_alphaneumeric = String.replace(query, ~r/[^a-zA-Z0-9]/, "")

    media_version_query =
      from(
        mv in MediaVersion,
        where:
          fragment("? @@ to_tsquery('simple', ?)", mv.searchable, ^query) or
            ilike(mv.source_url, ^"%#{query_only_alphaneumeric}%"),
        join: m in assoc(mv, :media),
        join: p in assoc(m, :project),
        join: pm in assoc(p, :memberships),
        on: pm.user_id == ^user.id,
        where: not is_nil(pm),
        order_by: [
          desc: fragment("ts_rank_cd(?, to_tsquery('simple', ?))", mv.searchable, ^query),
          desc: mv.inserted_at
        ],
        limit: 3,
        preload: [media: [:project]]
      )

    media_query =
      from(
        m in Media,
        where:
          fragment("? @@ to_tsquery('simple', ?)", m.searchable, ^query) or
            ilike(m.attr_description, ^"%#{query_only_alphaneumeric}%") or
            ilike(m.slug, ^"%#{query_only_alphaneumeric}%"),
        join: p in assoc(m, :project),
        join: pm in assoc(p, :memberships),
        on: pm.user_id == ^user.id,
        where: not is_nil(pm),
        order_by: [
          desc: fragment("ts_rank_cd(?, to_tsquery('simple', ?))", m.searchable, ^query),
          desc: m.inserted_at
        ],
        limit: 3,
        preload: [:project]
      )

    users_query =
      from(
        u in User,
        where:
          u.username != "atlos" and
            (fragment("? @@ to_tsquery('simple', ?)", u.searchable, ^query) or
               ilike(u.username, ^"%#{query_only_alphaneumeric}%")),
        order_by: [
          desc: fragment("ts_rank_cd(?, to_tsquery('simple', ?))", u.searchable, ^query),
          desc: u.inserted_at
        ],
        limit: 3
      )

    projects_query =
      from(
        p in Project,
        where:
          fragment("? @@ to_tsquery('simple', ?)", p.searchable, ^query) or
            ilike(p.name, ^"%#{query_only_alphaneumeric}%"),
        join: pm in assoc(p, :memberships),
        on: pm.user_id == ^user.id,
        where: not is_nil(pm),
        order_by: [
          desc: fragment("ts_rank_cd(?, to_tsquery('simple', ?))", p.searchable, ^query),
          desc: p.inserted_at
        ],
        limit: 3
      )

    updates_query =
      from(
        u in Update,
        where: fragment("? @@ to_tsquery('simple', ?)", u.searchable, ^query),
        join: m in assoc(u, :media),
        join: p in assoc(m, :project),
        join: pm in assoc(p, :memberships),
        on: pm.user_id == ^user.id,
        where: not is_nil(pm),
        order_by: [
          desc: fragment("ts_rank_cd(?, to_tsquery('simple', ?))", u.searchable, ^query),
          desc: u.inserted_at
        ],
        limit: 3
      )
      |> Platform.Updates.preload_fields()

    # Run each query in parallel
    [media_version_results, media_results, users_results, projects_results, updates_results] =
      Task.await_many([
        Task.async(fn ->
          Repo.all(media_version_query)
          |> Enum.filter(fn item -> Permissions.can_view_media_version?(user, item) end)
        end),
        Task.async(fn ->
          Repo.all(media_query)
          |> Enum.filter(fn item -> Permissions.can_view_media?(user, item) end)
        end),
        Task.async(fn ->
          if String.length(query) < 3 do
            []
          else
            Repo.all(users_query)
          end
        end),
        Task.async(fn ->
          Repo.all(projects_query)
          |> Enum.filter(fn item -> Permissions.can_view_project?(user, item) end)
        end),
        Task.async(fn ->
          Repo.all(updates_query)
          |> Enum.filter(fn item -> Permissions.can_view_update?(user, item) end)
        end)
      ])

    %{
      media_versions: media_version_results,
      media: media_results,
      users: users_results,
      projects: projects_results,
      updates: updates_results
    }
  end
end
