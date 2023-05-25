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

  @doc """
  Changeset for project attributes. Note that to change options, you must pass
  in a JSON array of options (in the `options_json` field), rather than the
  options themselves.
  """
  def changeset(%__MODULE__{} = attribute, attrs \\ %{}) do
    json_options =
      Map.get(attrs, "options_json", Jason.encode!(attribute.options))
      |> then(&if &1 == "", do: Jason.encode!(attribute.options), else: &1)

    attribute
    |> cast(attrs, [:name, :type, :options_json, :id, :description])
    |> cast(%{options_json: json_options}, [:options_json])
    |> cast(
      %{options: Jason.decode!(json_options)},
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

  def default_attributes() do
    [
      %__MODULE__{
        name: "Incident Type",
        type: :multi_select,
        description: "What kind of incident is this?",
        options:
          Platform.Material.Attribute.options(Platform.Material.Attribute.get_attribute(:type))
      },
      %__MODULE__{
        name: "Reported Near",
        type: :text,
        description: "Where was the incident reported to be near?"
      },
      %__MODULE__{
        name: "Impact",
        type: :multi_select,
        description: "What is damaged, harmed, or lost in this incident?",
        options:
          Platform.Material.Attribute.options(Platform.Material.Attribute.get_attribute(:impact))
      },
      %__MODULE__{
        name: "Equipment Used",
        type: :multi_select,
        description:
          "What equipment — weapon, military infrastructure, etc. — is used in the incident?",
        options:
          Platform.Material.Attribute.options(
            Platform.Material.Attribute.get_attribute(:equipment)
          )
      }
    ]
  end

  def does_project_have_default_attributes?(%Platform.Projects.Project{} = project) do
    project.attributes
    |> Enum.all?(fn attribute ->
      with default <- Enum.find(default_attributes(), &(&1.name == attribute.name)),
           true <- default != nil,
           true <- default.type == attribute.type,
           true <- default.options == attribute.options,
           true <- default.description == attribute.description do
        true
      else
        _ -> false
      end
    end)
  end
end
