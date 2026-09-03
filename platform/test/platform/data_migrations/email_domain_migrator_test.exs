defmodule Platform.DataMigrations.EmailDomainMigratorTest do
  use Platform.DataCase, async: false

  import ExUnit.CaptureLog
  import Platform.AccountsFixtures

  alias Platform.Accounts
  alias Platform.Accounts.{User, UserToken}
  alias Platform.DataMigrations.EmailDomainMigrator, as: Migrator

  # config/test.exs sets the Logger level to :warning; the auditor logs at :notice.
  setup do
    previous = Logger.level()
    Logger.configure(level: :notice)
    on_exit(fn -> Logger.configure(level: previous) end)
    :ok
  end

  @old "old.org"
  @new "new.org"
  @opts [verbose: false]

  defp user_at(email, attrs \\ %{}) do
    user_fixture(Map.merge(%{email: email}, attrs))
  end

  defp reload(%User{id: id}), do: Repo.get!(User, id)

  defp token_contexts(%User{id: id}) do
    Repo.all(
      from(t in UserToken, where: t.user_id == ^id, select: t.context, order_by: t.context)
    )
  end

  defp reset_token(user) do
    extract_user_token(&Accounts.deliver_user_reset_password_instructions(user, &1))
  end

  defp confirm_token(user) do
    extract_user_token(&Accounts.deliver_user_confirmation_instructions(user, &1))
  end

  defp set_billing_expiry(user) do
    {:ok, user} =
      Accounts.update_user_billing(user, %{
        billing_expires_at:
          DateTime.utc_now() |> DateTime.add(24, :hour) |> DateTime.truncate(:second)
      })

    user
  end

  describe "argument validation" do
    test "rejects empty, same, or malformed domains without touching the database" do
      user = user_at("a@#{@old}")

      assert {:error, :empty_domain} = Migrator.run("", @new, @opts)
      assert {:error, :empty_domain} = Migrator.run(@old, "  ", @opts)
      assert {:error, :same_domain} = Migrator.run(@old, "OLD.org", @opts)
      assert {:error, :domain_contains_at} = Migrator.run("x@#{@old}", @new, @opts)
      assert {:error, :domain_contains_at} = Migrator.run(@old, "@a@b", @opts)
      assert {:error, :domain_contains_whitespace} = Migrator.run(@old, "new .org", @opts)

      assert reload(user).email == "a@#{@old}"
    end

    test "tolerates a leading @ and surrounding whitespace" do
      user = user_at("a@#{@old}")
      assert {:ok, [_]} = Migrator.run(" @#{@old} ", "@#{@new}", [dry_run: false] ++ @opts)
      assert reload(user).email == "a@#{@new}"
    end
  end

  describe "dry run (the default)" do
    test "reports the plan but changes nothing" do
      alice = user_at("alice@#{@old}") |> set_billing_expiry()
      _reset = reset_token(alice)
      _confirm = confirm_token(alice)
      bystander = user_at("bob@elsewhere.org")

      assert {:dry_run, entries} = Migrator.run(@old, @new, @opts)

      assert [
               %{
                 username: username,
                 old_email: "alice@old.org",
                 new_email: "alice@new.org",
                 tokens_deleted: 2
               }
             ] =
               entries

      assert username == alice.username

      # Nothing persisted.
      reloaded = reload(alice)
      assert reloaded.email == "alice@#{@old}"
      assert reloaded.billing_expires_at == alice.billing_expires_at
      assert token_contexts(alice) == ["confirm", "reset_password"]
      assert reload(bystander).email == "bob@elsewhere.org"
    end

    test "emits no audit events" do
      user_at("alice@#{@old}")

      log =
        capture_log([level: :notice], fn ->
          {:dry_run, _} = Migrator.run(@old, @new, @opts)
        end)

      refute log =~ "email_domain_changed"
    end
  end

  describe "applying the change" do
    test "rewrites only exact-domain matches, preserving local part and case" do
      alice = user_at("alice@#{@old}")
      # Mixed case in both halves; citext stores it verbatim.
      bob = user_at("Bob.Smith+tag@OLD.ORG")
      # Look-alike domains that must NOT be touched.
      sub = user_at("carol@sub.#{@old}")
      prefix = user_at("dave@not#{@old}")
      suffix = user_at("erin@#{@old}.evil")
      other = user_at("frank@#{@new}")

      assert {:ok, entries} = Migrator.run(@old, @new, [dry_run: false] ++ @opts)
      assert length(entries) == 2

      assert reload(alice).email == "alice@#{@new}"
      assert reload(bob).email == "Bob.Smith+tag@#{@new}"
      assert reload(sub).email == "carol@sub.#{@old}"
      assert reload(prefix).email == "dave@not#{@old}"
      assert reload(suffix).email == "erin@#{@old}.evil"
      assert reload(other).email == "frank@#{@new}"
    end

    test "leaves every other user column alone" do
      alice =
        user_at("alice@#{@old}")
        |> then(fn u ->
          {:ok, u} = Accounts.update_user_admin(u, %{roles: [:admin]})
          u
        end)

      {:ok, %{user: alice}} =
        Ecto.Multi.new()
        |> Ecto.Multi.update(:user, User.confirm_changeset(alice))
        |> Repo.transaction()

      before = reload(alice)
      assert {:ok, [_]} = Migrator.run(@old, @new, [dry_run: false] ++ @opts)
      after_ = reload(alice)

      assert after_.email == "alice@#{@new}"
      assert after_.billing_expires_at == nil

      untouched = [
        :id,
        :username,
        :hashed_password,
        :confirmed_at,
        :roles,
        :has_mfa,
        :otp_secret,
        :recovery_codes,
        :billing_customer_id,
        :billing_flags,
        :inserted_at
      ]

      for field <- untouched do
        assert Map.get(after_, field) == Map.get(before, field), "#{field} changed"
      end
    end

    test "the user can log in with the new address and password, not the old one" do
      alice = user_at("alice@#{@old}")
      assert {:ok, _} = Migrator.run(@old, @new, [dry_run: false] ++ @opts)

      assert %User{id: id} =
               Accounts.get_user_by_email_and_password("alice@#{@new}", valid_user_password())

      assert id == alice.id
      # citext: case-insensitive login still works.
      assert %User{} =
               Accounts.get_user_by_email_and_password("ALICE@NEW.ORG", valid_user_password())

      refute Accounts.get_user_by_email_and_password("alice@#{@old}", valid_user_password())
    end

    test "deletes confirm and reset tokens of migrated users, keeps sessions, and leaves other users' tokens alone" do
      alice = user_at("alice@#{@old}")
      alice_reset = reset_token(alice)
      _alice_confirm = confirm_token(alice)
      alice_session = Accounts.generate_user_session_token(alice)

      bob = user_at("bob@elsewhere.org")
      bob_reset = reset_token(bob)
      _bob_confirm = confirm_token(bob)

      # Sanity: everything resolves before the migration.
      assert %User{id: alice_id} = Accounts.get_user_by_reset_password_token(alice_reset)
      assert alice_id == alice.id

      assert {:ok, [%{tokens_deleted: 2}]} = Migrator.run(@old, @new, [dry_run: false] ++ @opts)

      assert token_contexts(alice) == ["session"]
      assert %User{id: ^alice_id} = Accounts.get_user_by_session_token(alice_session)
      refute Accounts.get_user_by_reset_password_token(alice_reset)

      assert token_contexts(bob) == ["confirm", "reset_password"]
      assert %User{id: bob_id} = Accounts.get_user_by_reset_password_token(bob_reset)
      assert bob_id == bob.id
    end

    test "a fresh reset-password flow works end to end after the migration" do
      alice = user_at("alice@#{@old}")
      assert {:ok, _} = Migrator.run(@old, @new, [dry_run: false] ++ @opts)

      migrated = Accounts.get_user_by_email("alice@#{@new}")
      assert migrated.id == alice.id

      token = reset_token(migrated)
      assert %User{id: id} = Accounts.get_user_by_reset_password_token(token)
      assert id == alice.id

      assert {:ok, _} =
               Accounts.reset_user_password(migrated, %{
                 password: "a brand new password!",
                 password_confirmation: "a brand new password!"
               })

      assert %User{} =
               Accounts.get_user_by_email_and_password("alice@#{@new}", "a brand new password!")
    end

    test "clears billing_expires_at only for migrated users" do
      alice = user_at("alice@#{@old}") |> set_billing_expiry()
      bob = user_at("bob@elsewhere.org") |> set_billing_expiry()
      assert alice.billing_expires_at

      assert {:ok, _} = Migrator.run(@old, @new, [dry_run: false] ++ @opts)

      assert reload(alice).billing_expires_at == nil
      assert reload(bob).billing_expires_at == bob.billing_expires_at
    end

    test "writes one audit event per migrated user, after commit" do
      alice = user_at("alice@#{@old}")
      bob = user_at("bob@#{@old}")

      log =
        capture_log([level: :notice], fn ->
          {:ok, entries} = Migrator.run(@old, @new, [dry_run: false] ++ @opts)
          assert length(entries) == 2
        end)

      assert log =~ ~s([auditor] email_domain_changed)
      assert log =~ ~s("old_email":"alice@old.org")
      assert log =~ ~s("new_email":"alice@new.org")
      assert log =~ ~s("username":"#{alice.username}")
      assert log =~ ~s("username":"#{bob.username}")
      assert log =~ ~s("user_id":"#{alice.id}")
    end

    test "is idempotent: a second run finds nothing to do" do
      user_at("alice@#{@old}")
      assert {:ok, [_]} = Migrator.run(@old, @new, [dry_run: false] ++ @opts)
      assert {:ok, []} = Migrator.run(@old, @new, [dry_run: false] ++ @opts)
      assert {:dry_run, []} = Migrator.run(@old, @new, @opts)
    end

    test "handles a larger batch in one transaction" do
      users = for i <- 1..60, do: user_at("person#{i}@#{@old}")
      _ = user_at("outsider@elsewhere.org")

      assert {:ok, entries} = Migrator.run(@old, @new, [dry_run: false] ++ @opts)
      assert length(entries) == 60

      # Report is ordered by old email (citext ordering), and every user moved.
      assert Enum.map(entries, & &1.old_email) ==
               Enum.sort_by(entries, & &1.old_email) |> Enum.map(& &1.old_email)

      for u <- users do
        assert reload(u).email == String.replace(u.email, "@#{@old}", "@#{@new}")
      end

      assert Repo.aggregate(from(u in User, where: like(u.email, "%@old.org")), :count) == 0
      assert Repo.aggregate(from(u in User, where: like(u.email, "%@new.org")), :count) == 60
    end
  end

  describe "rollback" do
    test "an address collision at the new domain aborts the whole batch" do
      alice = user_at("alice@#{@old}") |> set_billing_expiry()
      _alice_reset = reset_token(alice)
      bob = user_at("bob@#{@old}")
      # Existing account that alice@old.org would collide with, in a different case.
      squatter = user_at("ALICE@#{@new}")

      assert {:error, {:invalid, username, %{email: errors}}} =
               Migrator.run(@old, @new, [dry_run: false] ++ @opts)

      assert username == alice.username
      assert errors == ["has already been taken"]

      # Nothing changed for anyone, including users processed before the failure.
      assert reload(alice).email == "alice@#{@old}"
      assert reload(alice).billing_expires_at == alice.billing_expires_at
      assert token_contexts(alice) == ["reset_password"]
      assert reload(bob).email == "bob@#{@old}"
      assert reload(squatter).email == "ALICE@#{@new}"
    end

    test "a new address over the 160-character limit aborts the whole batch" do
      long_local = String.duplicate("x", 150)
      # 150 + 1 + 5 = 156 chars: valid at the old domain...
      long = user_at("#{long_local}@a.io")
      short = user_at("s@a.io")
      # ...but 150 + 1 + 12 = 163 at the new one.
      new_domain = "abcdefgh.org"

      assert {:error, {:invalid, username, %{email: errors}}} =
               Migrator.run("a.io", new_domain, [dry_run: false] ++ @opts)

      assert username == long.username
      assert errors == ["should be at most 160 character(s)"]
      assert reload(long).email == "#{long_local}@a.io"
      assert reload(short).email == "s@a.io"
    end

    test "dry run also surfaces the collision" do
      _alice = user_at("alice@#{@old}")
      _squatter = user_at("alice@#{@new}")

      assert {:error, {:invalid, _, %{email: ["has already been taken"]}}} =
               Migrator.run(@old, @new, @opts)
    end
  end

  describe "plan/2" do
    test "lists pairs without writing" do
      alice = user_at("alice@#{@old}")
      assert [{%User{id: id}, "alice@#{@new}"}] = Migrator.plan(@old, @new)
      assert id == alice.id
      assert reload(alice).email == "alice@#{@old}"
    end
  end
end
