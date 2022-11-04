defmodule PlatformWeb.SPIController do
  use PlatformWeb, :controller
  require Ecto.Query

  alias Platform.Accounts

  def user_search(conn, params) do
    query = Map.get(params, "query", "")

    # TODO: Could improve this to do the search at the database level.
    json(conn, %{
      results:
        Accounts.get_all_users()
        |> Enum.filter(&String.starts_with?(&1.username, query))
        |> Enum.take(5)
        |> Enum.map(&%{username: &1.username, bio: &1.bio, flair: &1.flair})
    })
  end
end
