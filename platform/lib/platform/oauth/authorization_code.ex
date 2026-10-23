defmodule Platform.OAuth.AuthorizationCode do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "oauth_authorization_codes" do
    field :code_hash, :binary
    field :scopes, {:array, :string}, default: []
    field :redirect_uri, :string
    field :code_challenge, :string
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime

    belongs_to :client, Platform.OAuth.Client
    belongs_to :user, Platform.Accounts.User

    timestamps()
  end
end
