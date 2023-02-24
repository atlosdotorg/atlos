defmodule Platform.Projects.ProjectAttribute do
  use Ecto.Schema
  import Ecto.Changeset

  alias Platform.Material.Attribute

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field(:name, :string)
    field(:description, :string, default: "")
    field(:type, Ecto.Enum, values: [:select, :text, :date, :multi_select])
    field(:options, {:array, :string}, default: [])

    # JSON array of options
    field(:options_json, :string, virtual: true)
  end

  def compatible_types(current_type) do
    case current_type do
      :select -> [:select, :multi_select]
      :multi_select -> [:multi_select]
      :text -> [:text]
      :date -> [:date]
      nil -> [:select, :multi_select, :text, :date]
      other -> [other]
    end
  end

  def changeset(%__MODULE__{} = attribute, attrs \\ %{}) do
    options =
      Map.get(attrs, "options_json", Jason.encode!(attribute.options))
      |> then(&if &1 == "", do: Jason.encode!(attribute.options), else: &1)

    attribute
    |> cast(attrs, [:name, :type, :options_json, :id, :description])
    |> put_change(:options_json, options)
    |> cast(
      %{options: Jason.decode!(options)},
      [:options]
    )
    |> validate_required([:name, :type])
    |> validate_length(:name, min: 1, max: 40)
    |> validate_length(:description, min: 0, max: 240)
    |> validate_inclusion(:type, [:select, :text, :date, :multi_select])
    |> validate_change(:type, fn :type, type ->
      if type != attribute.type and not Enum.member?(compatible_types(attribute.type), type) do
        [type: "This is an invalid type for this attribute."]
      else
        []
      end
    end)
    |> validate_length(:options, min: 1, max: 256)
    |> then(fn changeset ->
      if Enum.member?([:select, :multi_select], get_field(changeset, :type)) do
        changeset
        |> validate_required([:options])
        |> validate_change(:options, fn :options, options ->
          if Enum.any?(options, fn option -> String.length(option) > 50 end) do
            [options: "An option cannot be longer than 50 characters"]
          else
            []
          end
        end)
        |> validate_change(:options, fn :options, options ->
          if Enum.count(options) > 256 do
            [options: "You may have at most 256 options."]
          else
            []
          end
        end)
        |> validate_change(:options, fn :options, options ->
          if Enum.count(options) != Enum.count(Enum.uniq(options)) do
            [options: "You may not have duplicate options."]
          else
            []
          end
        end)
      else
        changeset
      end
    end)
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
      description: attribute.description,
      pane: :attributes,
      required: false
    }
  end
end
