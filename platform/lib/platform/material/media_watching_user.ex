defmodule Platform.Material.MediaSubscription do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Material.Media
  alias Platform.Accounts.User

  schema "media_subscriptions" do
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
