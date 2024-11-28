defmodule Platform.Projects.ProjectAttributeGroup do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:name]}
  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field(:name, :string)
    field(:description, :string, default: "")
    field(:color, :string, default: "#808080")
    field(:show_in_creation_form, :boolean, default: true)
    # These can be a mix of binary IDs and string attributes, for core vs custom attributes
    # Source of truth for membership but not ordering
    field(:member_ids, {:array, :string}, default: [])
    field(:ordering, :integer, default: 0)
  end

  @doc """
  Changeset for project attribute groups.
  """
  def changeset(%__MODULE__{} = attribute, attrs \\ %{}) do
    attribute
    |> cast(attrs, [:name, :show_in_creation_form, :member_ids, :description, :ordering, :color])
    # Validate that "color" matches a hex color code via regex
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/)
    |> validate_length(:name, min: 1, max: 240)
    |> validate_length(:description, max: 3000)
    |> validate_required(:name)
  end
end
