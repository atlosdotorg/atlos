defmodule Platform.Projects.CustomAttribute do
  use Ecto.Schema
  import Ecto.Changeset

  schema "attribute" do
    field(:name, :string)
    field(:type, Ecto.Enum, values: [:select, :text, :date, :multi_select])
    field(:options, {:array, :string}, default: [])

    timestamps()
  end

  def changeset(attribute, attrs) do
    attribute
    |> cast(attrs, [:name, :type, :options])
    |> validate_required([:name, :type])
    |> validate_length(:name, min: 1, max: 40)
    |> validate_inclusion(:type, [:select, :text, :date, :multi_select])
    |> validate_length(:options, min: 1, max: 256)
  end
end
