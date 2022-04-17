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
alias Platform.Material

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

random_users =
  Enum.map(1..50, fn _ ->
    {:ok, account} =
      Accounts.register_user(%{
        email: Faker.Internet.email(),
        username: Faker.Internet.user_name(),
        password: "localhost123"
      })

    Accounts.update_user_profile(account, %{
      bio: Faker.Lorem.characters(Enum.random(10..240)),
      profile_photo_file: Faker.Internet.image_url()
    })

    account
  end)

random_media =
  Enum.map(1..10000, fn _ ->
    Material.create_media_audited(Enum.random(random_users), %{
      description: Faker.StarWars.quote(),
      attr_sensitive:
        if(Enum.random(0..10) < 2,
          do: [
            Enum.random(Material.Attribute.options(Material.Attribute.get_attribute(:sensitive)))
          ],
          else: ["Not Sensitive"]
        )
    })
  end)
