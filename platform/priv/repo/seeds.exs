# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Platform.Repo.insert!(%Platform.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Platform.Accounts

{:ok, regular} =
  Accounts.register_user(%{email: "user@localhost", username: "user", password: "localhost123"})

{:ok, muted} =
  Accounts.register_user(%{email: "muted@localhost", username: "muted", password: "localhost123"})

{:ok, banned} =
  Accounts.register_user(%{
    email: "banned@localhost",
    username: "banned",
    password: "localhost123"
  })

{:ok, admin} =
  Accounts.register_user(%{
    email: "admin@localhost",
    username: "admin",
    password: "localhost123",
    roles: [:admin]
  })

{:ok, _} = Accounts.update_user_access(admin, %{roles: [:admin]})
{:ok, _} = Accounts.update_user_access(muted, %{restrictions: [:muted]})
{:ok, _} = Accounts.update_user_access(muted, %{restrictions: [:banned]})
