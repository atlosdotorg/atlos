defmodule Platform.Repo.Migrations.CreateOAuthTables do
  use Ecto.Migration

  def change do
    # Clients registered through OAuth dynamic client registration (RFC 7591).
    # All clients are public clients (no client secret); PKCE protects the flow.
    create table(:oauth_clients, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :client_id, :string, null: false
      add :client_name, :string, null: false
      add :redirect_uris, {:array, :string}, null: false, default: []

      timestamps()
    end

    create unique_index(:oauth_clients, [:client_id])

    # Short-lived, single-use authorization codes. Only a SHA-256 hash of the
    # code is stored.
    create table(:oauth_authorization_codes, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :code_hash, :binary, null: false

      add :client_id, references(:oauth_clients, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :scopes, {:array, :string}, null: false, default: []
      add :redirect_uri, :text, null: false
      add :code_challenge, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime

      timestamps()
    end

    create unique_index(:oauth_authorization_codes, [:code_hash])

    # A grant is one user's authorization of one client, covering every
    # project the user belongs to. It holds the current access and refresh
    # tokens (both stored as SHA-256 hashes); refreshing rotates both.
    create table(:oauth_grants, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :access_token_hash, :binary, null: false
      add :refresh_token_hash, :binary, null: false

      add :client_id, references(:oauth_clients, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :authorization_code_id,
          references(:oauth_authorization_codes, type: :binary_id, on_delete: :nilify_all)

      add :scopes, {:array, :string}, null: false, default: []
      add :access_token_expires_at, :utc_datetime, null: false
      add :refresh_token_expires_at, :utc_datetime, null: false
      add :revoked_at, :utc_datetime
      add :last_used_at, :utc_datetime

      timestamps()
    end

    create unique_index(:oauth_grants, [:access_token_hash])
    create unique_index(:oauth_grants, [:refresh_token_hash])
    create index(:oauth_grants, [:user_id])
    create index(:oauth_grants, [:authorization_code_id])
  end
end
