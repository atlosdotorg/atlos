defmodule Platform.Material.Media do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Utils
  alias Platform.Material.Media.Attribute

  schema "media" do
    # Core uneditable data
    field :slug, :string, autogenerate: {Utils, :generate_media_slug, []}

    # Core editable data
    field :description, :string

    # Metadata Attributes
    field :attr_sensitive, {:array, :string}

    # "Normal" Attributes
    field :attr_time_of_day, :string

    # Metadata
    timestamps()
    has_many :versions, Platform.Material.MediaVersion
  end

  @doc false
  def changeset(media, attrs) do
    media
    |> cast(attrs, [:description, :attr_sensitive])
    |> validate_required([:description])

    # These are special attributes, since we define it at creation time. Eventually, it'd be nice to unify this logic with the attribute-specific editing logic.
    |> Attribute.validate_attribute(Attribute.get_attribute(:sensitive))
    |> Attribute.validate_attribute(Attribute.get_attribute(:description))
  end
end

defmodule Platform.Material.Media.Attribute do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  defstruct [
    :schema_field,
    :type,
    :label,
    :options,
    :max_length,
    :min_length,
    :pane,
    :required,
    :custom_validation
  ]

  defp attributes() do
    %{
      sensitive: %Attribute{
        schema_field: :attr_sensitive,
        type: :multi_select,
        options: [
          "Not Sensitive",
          "Threatens Civilian Safety",
          "Graphic Violence",
          "Deleted by Source",
          "Deceptive or Misleading"
        ],
        label: "Sensitivity",
        min_length: 1,
        pane: :metadata,
        required: true,
        custom_validation: fn :attr_sensitive, vals ->
          if Enum.member?(vals, "Not Sensitive") && length(vals) > 1 do
            [attr_sensitive: "If the media is 'Not Sensitive,' no other options may be selected"]
          else
            []
          end
        end
      },
      description: %Attribute{
        schema_field: :description,
        type: :text,
        max_length: 240,
        min_length: 8,
        label: "Description",
        pane: :metadata,
        required: true
      },
      time_of_day: %Attribute{
        schema_field: :attr_time_of_day,
        type: :select,
        options: ["Night", "Day"],
        label: "Time of Day",
        pane: :attributes,
        required: false
      }
    }
  end

  @doc """
  Get the names of the attributes that are available for the given media.
  """
  def set_for_media(media, pane \\ nil) do
    Enum.filter(list_attributes(), fn attr_name ->
      attr = get_attribute(attr_name)
      Map.get(media, attr.schema_field) != nil && (pane == nil || attr.pane == pane)
    end)
  end

  def unset_for_media(media, pane \\ nil) do
    set = set_for_media(media)

    set
    |> Enum.filter(&(!Enum.member?(set, &1)))
    |> Enum.filter(&(pane == nil || get_attribute(&1).pane == pane))
  end

  def get_attribute(name) do
    attributes()[name]
  end

  def list_attributes() do
    Map.keys(attributes())
  end

  def changeset(media, %Attribute{} = attribute, attrs \\ %{}) do
    media
    |> cast(attrs, [attribute.schema_field])
    |> validate_attribute(attribute)
  end

  def validate_attribute(changeset, %Attribute{} = attribute) do
    validations =
      case attribute.type do
        :multi_select ->
          changeset
          |> validate_subset(attribute.schema_field, attribute.options)
          |> validate_required(attribute.schema_field)
          |> validate_length(attribute.schema_field,
            min: attribute.min_length,
            max: attribute.max_length
          )

        :select ->
          changeset
          |> validate_inclusion(attribute.schema_field, attribute.options)
          |> validate_required(attribute.schema_field)

        :text ->
          changeset
          |> validate_length(attribute.schema_field,
            min: attribute.min_length,
            max: attribute.max_length
          )
      end

    if attribute.custom_validation != nil do
      validations |> validate_change(attribute.schema_field, attribute.custom_validation)
    else
      validations
    end
  end
end
