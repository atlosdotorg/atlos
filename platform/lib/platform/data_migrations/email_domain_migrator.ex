defmodule Platform.DataMigrations.EmailDomainMigrator do
  @moduledoc """
  One-off operator tool that moves every user whose email address is at
  `old_domain` to `new_domain`, keeping the local part exactly as stored.

  Intended to be run by hand from a remote console. It is a dry run unless
  you pass `dry_run: false`:

      alias Platform.DataMigrations.EmailDomainMigrator
      EmailDomainMigrator.run("old.org", "new.org")                 # report only
      EmailDomainMigrator.run("old.org", "new.org", dry_run: false) # apply

  For each affected user, inside a single transaction:

    * the email is rewritten through `Platform.Accounts.change_user_email/2`,
      so format, length and uniqueness validation apply and any failure rolls
      back the whole batch;
    * outstanding `confirm` and `reset_password` tokens are deleted, because
      `Platform.Accounts.UserToken.verify_email_token_query/2` compares the
      token's `sent_to` with the user's current email and they would fail
      anyway. Session tokens are untouched, so nobody is logged out;
    * `billing_expires_at` is cleared so `Platform.Billing.get_user_plan/1`
      re-pushes the new address to Stripe on the user's next visit.

  After a successful (non dry-run) commit, one `:email_domain_changed` event per
  user is written through `Platform.Auditor`.
  """

  import Ecto.Query

  alias Platform.Accounts
  alias Platform.Accounts.{User, UserToken}
  alias Platform.Auditor
  alias Platform.Repo

  @token_contexts ["confirm", "reset_password"]

  @type entry :: %{
          user_id: Ecto.UUID.t(),
          username: String.t(),
          old_email: String.t(),
          new_email: String.t(),
          tokens_deleted: non_neg_integer()
        }

  @doc """
  Runs the migration.

  Options:

    * `:dry_run` (default `true`) — plan and validate inside a transaction, then
      roll back.
    * `:verbose` (default `true`) — print a human-readable report to stdout.

  Returns `{:dry_run, entries}`, `{:ok, entries}`, or `{:error, reason}`.
  """
  @spec run(String.t(), String.t(), keyword()) ::
          {:dry_run, [entry()]} | {:ok, [entry()]} | {:error, term()}
  def run(old_domain, new_domain, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, true)
    verbose = Keyword.get(opts, :verbose, true)

    with {:ok, old_domain, new_domain} <- normalize_domains(old_domain, new_domain) do
      plan = plan(old_domain, new_domain)
      collisions = collisions(plan)

      if verbose, do: print_plan(old_domain, plan, collisions)

      result =
        Repo.transaction(
          fn ->
            entries = Enum.map(plan, &migrate_user!/1)
            if dry_run, do: Repo.rollback({:dry_run, entries}), else: entries
          end,
          timeout: :infinity
        )

      case result do
        {:error, {:dry_run, entries}} ->
          if verbose,
            do: IO.puts("\nDRY RUN: #{length(entries)} users would be updated; rolled back.")

          {:dry_run, entries}

        {:ok, entries} ->
          Enum.each(entries, &Auditor.log(:email_domain_changed, &1))
          if verbose, do: IO.puts("\nDONE: #{length(entries)} users updated.")
          {:ok, entries}

        {:error, reason} ->
          if verbose, do: IO.puts("\nABORTED, nothing changed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @doc """
  Returns the `{user, new_email}` pairs that `run/3` would act on, without
  touching anything.
  """
  @spec plan(String.t(), String.t()) :: [{User.t(), String.t()}]
  def plan(old_domain, new_domain) do
    # The query guarantees the stored address ends in "@" <> old_domain in some
    # casing, so strip the suffix by length rather than by string match. That
    # preserves the local part byte-for-byte, including its case.
    suffix_len = String.length(old_domain) + 1

    old_domain
    |> users_at_domain_query()
    |> Repo.all()
    |> Enum.map(fn user ->
      {local, _} = String.split_at(user.email, -suffix_len)
      {user, local <> "@" <> new_domain}
    end)
  end

  defp users_at_domain_query(domain) do
    from(u in User,
      where: fragment("lower(split_part(?, '@', 2)) = lower(?)", u.email, ^domain),
      order_by: u.email
    )
  end

  defp collisions([]), do: []

  defp collisions(plan) do
    targets = Enum.map(plan, fn {_, email} -> email end)
    # users.email is citext, so `in` is already case-insensitive.
    Repo.all(from(u in User, where: u.email in ^targets, select: u.email))
  end

  defp migrate_user!({%User{} = user, new_email}) do
    changeset =
      user
      |> Accounts.change_user_email(%{email: new_email})
      |> Ecto.Changeset.put_change(:billing_expires_at, nil)

    case Repo.update(changeset) do
      {:ok, _updated} ->
        {tokens_deleted, _} =
          Repo.delete_all(
            from(t in UserToken,
              where: t.user_id == ^user.id and t.context in ^@token_contexts
            )
          )

        %{
          user_id: user.id,
          username: user.username,
          old_email: user.email,
          new_email: new_email,
          tokens_deleted: tokens_deleted
        }

      {:error, changeset} ->
        Repo.rollback({:invalid, user.username, changeset_errors(changeset)})
    end
  end

  defp normalize_domains(old_domain, new_domain) do
    old_domain = old_domain |> String.trim() |> String.trim_leading("@")
    new_domain = new_domain |> String.trim() |> String.trim_leading("@")

    cond do
      old_domain == "" or new_domain == "" ->
        {:error, :empty_domain}

      String.contains?(old_domain, "@") or String.contains?(new_domain, "@") ->
        {:error, :domain_contains_at}

      String.contains?(old_domain <> new_domain, [" ", "\t", "\n"]) ->
        {:error, :domain_contains_whitespace}

      String.downcase(old_domain) == String.downcase(new_domain) ->
        {:error, :same_domain}

      true ->
        {:ok, old_domain, new_domain}
    end
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp print_plan(old_domain, plan, collisions) do
    IO.puts("#{length(plan)} users match @#{old_domain}:")
    Enum.each(plan, fn {u, e} -> IO.puts("  #{u.username}: #{u.email} -> #{e}") end)

    if collisions != [] do
      IO.puts("\n!! #{length(collisions)} target addresses already exist (batch will abort):")
      Enum.each(collisions, &IO.puts("  #{&1}"))
    end
  end
end
