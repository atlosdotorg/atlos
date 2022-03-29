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

    # Attributes
    field :attr_sensitive, {:array, :string}

    # Metadata
    timestamps()
    has_many :versions, Platform.Material.MediaVersion
  end

  @doc false
  def changeset(media, attrs) do
    media
    |> cast(attrs, [:description, :attr_sensitive])
    |> validate_required([:description])
    |> validate_length(:description, min: 8, max: 240)
    # This is a special attribute, since we define it at creation time. Eventually, it'd be nice to unify this logic with the attribute-specific editing logic.
    |> Attribute.validate_attribute(Attribute.get_attribute(:sensitive))
  end
end

defmodule Platform.Material.Media.Attribute do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  defstruct [:schema_field, :type, :options, :label]

  defp attributes() do
    %{
      sensitive: %Attribute{
        schema_field: :attr_sensitive,
        type: :multi_select,
        options: ["Threatens Civilian Safety", "Graphic Violence"],
        label: "Sensitivity"
      }
    }
  end

  def get_attribute(name) do
    attributes()[name]
  end

  def list_attributes() do
    Map.keys(attributes())
  end

  def changeset(media, attrs, %Attribute{} = attribute) do
    media
    |> cast(attrs, [attribute.schema_field])
    |> validate_attribute(attribute)
  end

  def validate_attribute(changeset, %Attribute{} = attribute) do
    case attribute.type do
      :multi_select ->
        changeset |> validate_subset(attribute.schema_field, attribute.options)
    end
  end
end
