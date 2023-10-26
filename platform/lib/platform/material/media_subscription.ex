defmodule Platform.Material.MediaSubscription do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Material.Media
  alias Platform.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "media_subscriptions" do
    belongs_to :user, User, type: :binary_id
    belongs_to :media, Media, type: :binary_id

    timestamps()
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:user_id, :media_id])
    |> validate_required([:user_id, :media_id])
    |> unique_constraint(:media_id,
      name: :media_subscriptions_media_id_user_id_index,
      message: "Already subscribed"
    )
  end
end
