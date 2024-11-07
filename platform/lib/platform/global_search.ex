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
    query_lower_raw = String.trim(query) |> String.downcase()

    query_cleaned =
      String.trim(query)
      |> String.downcase()

    query_only_alphaneumeric = String.replace(query, ~r/[^a-zA-Z0-9\s\-]/, "")

    query_websearch =
      query_cleaned |> String.replace(~r/\s+/, " OR ") |> String.replace(~r/[^a-zA-Z0-9\s\-]/, "")

    media_version_query =
      from(
        mv in MediaVersion,
        where:
          fragment("? @@ websearch_to_tsquery('simple', ?)", mv.searchable, ^query_websearch) or
            ilike(mv.source_url, ^"%#{query_only_alphaneumeric}%") or
            fragment("LOWER(?) = ?", mv.source_url, ^query_lower_raw),
        join: m in assoc(mv, :media),
        join: p in assoc(m, :project),
        join: pm in assoc(p, :memberships),
        on: pm.user_id == ^user.id,
        where: not is_nil(pm),
        order_by: [
          asc:
            fragment(
              "case when ? then 0 else 1 end",
              ilike(mv.source_url, ^"%#{query_only_alphaneumeric}%") or
                fragment("LOWER(?) = ?", mv.source_url, ^query_lower_raw)
            ),
          desc:
            fragment(
              "ts_rank_cd(?, websearch_to_tsquery('simple', ?))",
              mv.searchable,
              ^query_websearch
            ),
          desc: mv.inserted_at
        ],
        limit: 3,
        preload: [media: [:project]],
        select: %{
          item: mv,
          exact_match:
            ilike(mv.source_url, ^"%#{query_only_alphaneumeric}%") or
              fragment("LOWER(?) = ?", mv.source_url, ^query_lower_raw),
          cd_rank:
            fragment(
              "ts_rank_cd(?, websearch_to_tsquery('simple', ?))",
              mv.searchable,
              ^query_websearch
            )
        }
      )

    media_query =
      from(
        m in Media,
        where:
          fragment("? @@ websearch_to_tsquery('simple', ?)", m.searchable, ^query_websearch) or
            ilike(m.attr_description, ^"%#{query_only_alphaneumeric}%") or
            ilike(m.searchable_text, ^"%#{query_cleaned}%") or
            ilike(m.slug, ^"%#{query_only_alphaneumeric}%"),
        join: p in assoc(m, :project),
        join: pm in assoc(p, :memberships),
        on: pm.user_id == ^user.id,
        where: not is_nil(pm),
        order_by: [
          asc:
            fragment(
              "case when ? then 0 else 1 end",
              ilike(m.attr_description, ^"%#{query_only_alphaneumeric}%") or
                ilike(m.slug, ^"%#{query_only_alphaneumeric}%")
            ),
          desc:
            fragment(
              "ts_rank_cd(?, websearch_to_tsquery('simple', ?))",
              m.searchable,
              ^query_websearch
            ),
          desc: m.inserted_at
        ],
        limit: 3,
        preload: [:project],
        select: %{
          item: m,
          exact_match:
            ilike(m.attr_description, ^"%#{query_only_alphaneumeric}%") or
              ilike(m.slug, ^"%#{query_only_alphaneumeric}%"),
          cd_rank:
            fragment(
              "ts_rank_cd(?, websearch_to_tsquery('simple', ?))",
              m.searchable,
              ^query_websearch
            )
        }
      )

    users_query =
      from(
        u in User,
        where:
          u.username != "atlos" and
            (fragment("? @@ websearch_to_tsquery('simple', ?)", u.searchable, ^query_websearch) or
               ilike(u.username, ^"%#{query_only_alphaneumeric}%")),
        order_by: [
          asc:
            fragment(
              "case when ? then 0 else 1 end",
              ilike(u.username, ^"%#{query_only_alphaneumeric}%")
            ),
          desc:
            fragment(
              "ts_rank_cd(?, websearch_to_tsquery('simple', ?))",
              u.searchable,
              ^query_websearch
            ),
          desc: u.inserted_at
        ],
        limit: 3,
        select: %{
          item: u,
          exact_match: ilike(u.username, ^"%#{query_only_alphaneumeric}%"),
          cd_rank:
            fragment(
              "ts_rank_cd(?, websearch_to_tsquery('simple', ?))",
              u.searchable,
              ^query_websearch
            )
        }
      )

    projects_query =
      from(
        p in Project,
        where:
          fragment("? @@ websearch_to_tsquery('simple', ?)", p.searchable, ^query_websearch) or
            ilike(p.name, ^"%#{query_only_alphaneumeric}%"),
        join: pm in assoc(p, :memberships),
        on: pm.user_id == ^user.id,
        where: not is_nil(pm),
        order_by: [
          asc:
            fragment(
              "case when ? then 0 else 1 end",
              ilike(p.name, ^"%#{query_only_alphaneumeric}%")
            ),
          desc:
            fragment(
              "ts_rank_cd(?, websearch_to_tsquery('simple', ?))",
              p.searchable,
              ^query_websearch
            ),
          desc: p.inserted_at
        ],
        limit: 3,
        select: %{
          item: p,
          exact_match: ilike(p.name, ^"%#{query_only_alphaneumeric}%"),
          cd_rank:
            fragment(
              "ts_rank_cd(?, websearch_to_tsquery('simple', ?))",
              p.searchable,
              ^query_websearch
            )
        }
      )

    updates_query =
      from(
        u in Update,
        where:
          fragment("? @@ websearch_to_tsquery('simple', ?)", u.searchable, ^query_websearch) or
            ilike(u.explanation, ^"%#{query_only_alphaneumeric}%") or
            ilike(u.explanation, ^"%#{query_lower_raw}%"),
        join: m in assoc(u, :media),
        join: p in assoc(m, :project),
        join: pm in assoc(p, :memberships),
        on: pm.user_id == ^user.id,
        where: not is_nil(pm),
        order_by: [
          asc:
            fragment(
              "case when ? then 0 else 1 end",
              ilike(u.explanation, ^"%#{query_only_alphaneumeric}%") or
                ilike(u.explanation, ^"%#{query_lower_raw}%")
            ),
          desc:
            fragment(
              "ts_rank_cd(?, websearch_to_tsquery('simple', ?))",
              u.searchable,
              ^query_websearch
            ),
          desc: u.inserted_at
        ],
        limit: 3,
        select: %{
          item: u,
          exact_match:
            ilike(u.explanation, ^"%#{query_only_alphaneumeric}%") or
              ilike(u.explanation, ^"%#{query_lower_raw}%"),
          cd_rank:
            fragment(
              "ts_rank_cd(?, websearch_to_tsquery('simple', ?))",
              u.searchable,
              ^query_websearch
            )
        }
      )
      |> Platform.Updates.preload_fields()

    # Run each query in parallel
    [media_version_results, media_results, users_results, projects_results, updates_results] =
      Task.await_many([
        Task.async(fn ->
          Repo.all(media_version_query)
          |> Enum.filter(fn item -> Permissions.can_view_media_version?(user, item.item) end)
        end),
        Task.async(fn ->
          Repo.all(media_query)
          |> Enum.filter(fn item -> Permissions.can_view_media?(user, item.item) end)
        end),
        Task.async(fn ->
          if String.length(query_websearch) < 3 do
            []
          else
            Repo.all(users_query)
          end
        end),
        Task.async(fn ->
          Repo.all(projects_query)
          |> Enum.filter(fn item -> Permissions.can_view_project?(user, item.item) end)
        end),
        Task.async(fn ->
          Repo.all(updates_query)
          |> Enum.filter(fn item -> Permissions.can_view_update?(user, item.item) end)
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
