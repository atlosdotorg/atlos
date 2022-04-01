defmodule Platform.Updates.Update do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Material.Media
  alias Platform.Material.Attribute

  schema "updates" do
    field :explanation, :string
    field :modified_attribute, Ecto.Enum, nullable: true, values: Attribute.attribute_names()
    field :new_value, :string, default: "null" # JSON-encoded data
    field :old_value, :string, default: "null" # JSON-encoded data

    belongs_to :user, Platform.Accounts.User
    belongs_to :media, Platform.Material.Media

    timestamps()
  end

  @doc false
  def changeset(update, attrs) do
    update
    |> cast(attrs, [:explanation, :old_value, :new_value, :modified_attribute])
    |> validate_required([:old_value, :new_value, :modified_attribute])
    |> validate_length(:explanation, min: 0, max: 5_000_000) # Don't worry --- the longest comments will be truncated
    |> validate_inclusion(:modified_attribute, Attribute.attribute_names())
  end
end
