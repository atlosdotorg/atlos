defmodule Platform.Projects.ProjectAttributeGroup do
  use Ecto.Schema
  import Ecto.Changeset

  alias Platform.Material.Attribute

  @derive {Jason.Encoder, only: [:name]}
  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field(:name, :string)
    # These can be a mix of binary IDs and string attributes, for core vs custom attributes
    field(:member_ids, {:array, :string}, default: [])
  end

  @doc """
  Changeset for project attribute groups.
  """
  def changeset(%__MODULE__{} = attribute, attrs \\ %{}) do
    attribute
    |> cast(attrs, [:name, :member_ids])
    |> validate_length(:name, min: 1, max: 240)
    |> validate_required(:name)
  end
end
