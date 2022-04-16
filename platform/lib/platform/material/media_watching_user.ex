defmodule Platform.Material.MediaWatchingUser do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Material.Media
  alias Platform.Accounts.User

  schema "media_watching_users" do
    belongs_to :user, User
    belongs_to :media, Media

    timestamps()
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:user_id, :media_id])
    |> validate_required([:user_id, :media_id])
  end
end
