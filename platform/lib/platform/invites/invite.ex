defmodule Platform.Invites.Invite do
  use Ecto.Schema
  import Ecto.Changeset

  schema "invites" do
    field :active, :boolean, default: false
    field :code, :string
    field :owner_id, :id

    timestamps()
  end

  @doc false
  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:code, :active])
    |> validate_required([:code, :active])
    |> unique_constraint(:code)
  end
end
