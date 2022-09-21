defmodule Platform.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :content, :string
    field :read, :boolean, default: false
    field :type, Ecto.Enum, values: [:update, :other]

    belongs_to :user, Platform.Accounts.User
    belongs_to :media, Platform.Material.Media
    belongs_to :update, Platform.Updates.Update

    timestamps()
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:read, :content, :type, :user_id, :media_id, :update_id])
    |> validate_required([:read, :content, :type, :user_id])
  end
end
