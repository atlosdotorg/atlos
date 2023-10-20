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

alias Platform.Projects
alias Platform.Accounts
alias Platform.Material

{:ok, regular} =
  Accounts.register_user(%{
    email: "user@localhost",
    invite_code: Accounts.get_valid_invite_code(),
    username: "user",
    password: "localhost123"
  })

{:ok, muted} =
  Accounts.register_user(%{
    email: "muted@localhost",
    invite_code: Accounts.get_valid_invite_code(),
    username: "muted",
    password: "localhost123"
  })

{:ok, suspended} =
  Accounts.register_user(%{
    email: "suspended@localhost",
    username: "suspended",
    password: "localhost123",
    invite_code: Accounts.get_valid_invite_code()
  })

{:ok, admin} =
  Accounts.register_user(
    %{
      email: "admin@localhost",
      username: "admin",
      password: "localhost123",
      roles: [:admin],
      invite_code: Accounts.get_valid_invite_code()
    },
    allow_special_users: true
  )

{:ok, admin} = Accounts.update_user_admin(admin, %{roles: [:admin]})
{:ok, muted} = Accounts.update_user_admin(muted, %{restrictions: [:muted]})
{:ok, suspended} = Accounts.update_user_admin(suspended, %{restrictions: [:suspended]})

IO.puts("Creating seed users")

random_users =
  Enum.map(1..20, fn _ ->
    {:ok, account} =
      Accounts.register_user(%{
        email: Faker.Internet.email(),
        username: Faker.Internet.user_name() |> String.replace(~r/[_\.]/, ""),
        password: "localhost123",
        invite_code: Accounts.get_valid_invite_code()
      })

    {:ok, account_updated} =
      Accounts.update_user_profile(account, %{
        profile_photo_file:
          "https://robohash.org/set_set1/bgset_bg1/#{Faker.Lorem.characters(1..20)}"
      })

    account_updated
  end)

IO.puts("Creating seed projects")

random_projects =
  Enum.map(1..25, fn _ ->
    {:ok, project} =
      Projects.create_project(
        %{
          "code" => Faker.Lorem.characters(3..5) |> to_string() |> String.upcase(),
          "name" => Faker.Company.name()
        },
        admin
      )

    # Add every user to the project
    Enum.each(random_users, fn user ->
      {:ok, _} =
        Projects.create_project_membership(%{
          username: user.username,
          project_id: project.id,
          role: :editor
        })
    end)

    project
  end)

IO.puts("Creating seed media")

random_media =
  Enum.map(1..250, fn _ ->
    creator = Enum.random(random_users)

    {:ok, media} =
      Material.create_media_audited(creator, %{
        attr_description: Faker.StarWars.quote() |> String.slice(0..230),
        project_id: Enum.random(random_projects).id,
        attr_sensitive:
          if(Enum.random(0..10) < 2,
            do: [
              Enum.random(
                Material.Attribute.options(Material.Attribute.get_attribute(:sensitive))
              )
            ],
            else: ["Not Sensitive"]
          ),
        attr_type: [
          Enum.random(Material.Attribute.options(Material.Attribute.get_attribute(:type)))
        ],
        attr_status: "To Do"
      })

    Material.create_media_version_audited(media, creator, %{
      file_location: "https://placekitten.com/#{Enum.random(50..1000)}/#{Enum.random(50..1000)}",
      file_size: Enum.random(10000..10_000_000),
      duration_seconds: 0,
      source_url: Faker.Internet.url(),
      mime_type: "image/jpg",
      client_name: "image.jpg"
    })

    Material.subscribe_user(media, creator)

    # Add geolocation to 30%
    if Enum.random(0..10) < 3 do
      attr = Material.Attribute.get_attribute(:geolocation)

      {:ok, _} =
        Material.update_media_attribute_audited(
          media,
          attr,
          Enum.random(random_users),
          %{
            "location" =>
              to_string(49 + :rand.uniform() * 30 - 15) <>
                ", " <> to_string(30 + :rand.uniform() * 16 - 8)
          }
        )
    end

    # Add status to 80%
    if Enum.random(0..9) < 8 do
      attr = Material.Attribute.get_attribute(:status)
      existing_value = Material.get_attribute_value(media, attr)
      new_value = Enum.random(attr.options -- [existing_value])

      # If it fails, nbd; the user may not have permission to set the status
      _ =
        Material.update_media_attribute_audited(
          media,
          attr,
          Enum.random(random_users),
          %{"attr_status" => new_value}
        )
    end
  end)
