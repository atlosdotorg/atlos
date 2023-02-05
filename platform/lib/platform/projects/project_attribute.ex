defmodule Platform.Projects.ProjectAttribute do
  use Ecto.Schema
  import Ecto.Changeset

  alias Platform.Material.Attribute

  embedded_schema do
    field(:name, :string)
    field(:type, Ecto.Enum, values: [:select, :text, :date, :multi_select])
    field(:options, {:array, :string}, default: [])

    # JSON array of options
    field(:options_json, :string, virtual: true)
    field(:delete, :boolean, virtual: true)
  end

  def changeset(%__MODULE__{} = attribute, attrs) do
    attribute
    |> cast(attrs, [:name, :type, :options_json, :id, :delete])
    |> put_change(:options_json, Map.get(attrs, "options_json", Jason.encode!(attribute.options)))
    |> put_change(
      :options,
      Jason.decode!(Map.get(attrs, "options_json", Jason.encode!(attribute.options)))
    )
    |> validate_required([:name, :type])
    |> validate_length(:name, min: 1, max: 40)
    |> validate_inclusion(:type, [:select, :text, :date, :multi_select])
    |> validate_length(:options, min: 1, max: 256)
    |> mark_for_deletion()
  end

  defp mark_for_deletion(changeset) do
    # If delete was set and it is true, let's change the action
    if get_change(changeset, :delete) do
      %{changeset | action: :delete}
    else
      changeset
    end
  end

  @doc """
  Convert the given ProjectAttribute into an attribute.
  """
  def to_attribute(%__MODULE__{} = attribute) do
    %Attribute{
      schema_field: :project_attributes,
      name: attribute.id,
      label: attribute.name,
      type: attribute.type,
      options: attribute.options,
      pane: :attributes,
      required: false
    }
  end
end
