defmodule Platform.Invites.Invite do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Utils
  alias Platform.Accounts
  alias __MODULE__

  schema "invites" do
    field :active, :boolean, default: true
    field :code, :string, autogenerate: {Invite, :generate_random_code, []}
    field :owner_id, :id

    # Accounts who have used the invite code to register
    has_many :users, Accounts.User

    timestamps()
  end

  def generate_random_code do
    Utils.generate_random_sequence(10)
  end

  @doc false
  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:active])
    |> validate_required([:active])
  end
end
