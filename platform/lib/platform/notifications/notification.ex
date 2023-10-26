defmodule Platform.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "notifications" do
    field :content, :string
    field :read, :boolean, default: false
    field :type, Ecto.Enum, values: [:update, :message]

    belongs_to :user, Platform.Accounts.User, type: :binary_id
    belongs_to :media, Platform.Material.Media, type: :binary_id
    belongs_to :update, Platform.Updates.Update, type: :binary_id

    timestamps()
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:read, :content, :type, :user_id, :media_id, :update_id])
    |> validate_required([:read, :type, :user_id])
  end
end
