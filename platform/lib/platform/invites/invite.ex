defmodule Platform.Invites.Invite do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Invites.InviteUse
  alias Platform.Utils
  alias Platform.Accounts
  alias __MODULE__

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "invites" do
    field :expires, :naive_datetime
    field :single_use, :boolean, default: true

    field :active, :boolean, default: true
    field :code, :string, autogenerate: {Invite, :generate_random_code, []}

    # Accounts who have used the invite code to register
    has_many :uses, InviteUse
    belongs_to :owner, Accounts.User, type: :binary_id

    # Access granted to users who use the invite code
    belongs_to :project, Platform.Projects.Project, type: :binary_id

    field :project_access_level, Ecto.Enum,
      values: [:owner, :manager, :editor, :viewer],
      default: :editor

    timestamps()
  end

  def generate_random_code do
    Utils.generate_random_sequence(16)
  end

  @doc false
  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:active, :owner_id, :expires, :single_use, :project_id, :project_access_level])
    |> validate_required([:active, :single_use])
  end
end
