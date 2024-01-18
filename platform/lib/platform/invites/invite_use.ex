defmodule Platform.Invites.InviteUse do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Accounts
  alias Platform.Invites.Invite

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "invite_uses" do
    belongs_to :user, Accounts.User, type: :binary_id
    belongs_to :invite, Invite, type: :binary_id

    timestamps()
  end

  @doc false
  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:user_id, :invite_id])
    |> validate_required([:user_id, :invite_id])
    |> unique_constraint([:user_id, :invite_id], name: :invite_uses_invite_id_user_id_index)
  end
end
