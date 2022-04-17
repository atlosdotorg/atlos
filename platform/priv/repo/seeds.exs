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

    {:ok, account_updated} = Accounts.update_user_profile(account, %{
      profile_photo_file: Faker.Avatar.image_url()
    })

    account_updated
  end)

random_media =
  Enum.map(1..10000, fn _ ->
    creator = Enum.random(random_users)
    {:ok, media} = Material.create_media_audited(creator, %{
      description: Faker.StarWars.quote() |> String.slice(0..230),
      attr_sensitive:
        if(Enum.random(0..10) < 2,
          do: [
            Enum.random(Material.Attribute.options(Material.Attribute.get_attribute(:sensitive)))
          ],
          else: ["Not Sensitive"]
        )
    })

    url = Faker.Internet.image_url()
    Material.create_media_version_audited(media, creator, %{
      file_location: url,
      file_size: Enum.random(10000..10000000),
      duration_seconds: 0,
      source_url: Faker.Internet.url(),
      mime_type: "image/jpg",
      client_name: "image.jpg",
      thumbnail_location: url
    })

    Material.subscribe_user(media, creator)

  end)
