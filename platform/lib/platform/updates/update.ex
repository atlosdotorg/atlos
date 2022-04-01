defmodule Platform.Updates.Update do
  use Ecto.Schema
  import Ecto.Changeset

  schema "updates" do
    field :explanation, :string
    field :modified_attribute, :string
    field :new_value, :string
    field :old_value, :string

    belongs_to :user, Platform.Accounts.User
    belongs_to :media, Platform.Material.Media

    timestamps()
  end

  @doc false
  def changeset(update, attrs) do
    update
    |> cast(attrs, [:explanation, :old_value, :new_value, :modified_attribute])
    |> validate_required([:explanation, :old_value, :new_value, :modified_attribute])
  end
end
