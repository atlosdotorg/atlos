defmodule Platform.OAuth.Grant do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "oauth_grants" do
    field :access_token_hash, :binary
    field :refresh_token_hash, :binary
    field :scopes, {:array, :string}, default: []
    field :access_token_expires_at, :utc_datetime
    field :refresh_token_expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :last_used_at, :utc_datetime

    belongs_to :client, Platform.OAuth.Client
    belongs_to :user, Platform.Accounts.User
    belongs_to :authorization_code, Platform.OAuth.AuthorizationCode

    timestamps()
  end
end
