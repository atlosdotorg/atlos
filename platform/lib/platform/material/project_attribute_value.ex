defmodule Platform.Material.ProjectAttributeValue do
  use Ecto.Schema
  import Ecto.Changeset

  alias Platform.Material.Attribute
  alias Platform.Material.Media
  alias Platform.Projects.ProjectAttribute

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "project_attribute_values" do
    field(:value, :map)

    belongs_to(:project_attribute, ProjectAttribute, on_replace: :delete, type: :binary_id)
    belongs_to(:media, Media, on_replace: :delete)

    field(:explanation, :string, virtual: true)

    timestamps()
  end

  def changeset(
        %__MODULE__{} = attribute_value,
        attrs,
        %Attribute{} = attr,
        %Media{} = media,
        opts \\ []
      ) do
    if attr.schema_field != :project_attributes do
      raise ArgumentError, "Attribute is not a project attribute"
    end

    cs =
      attribute_value
      |> cast(attrs, [:explanation])
      |> put_change(:media_id, media.id)
      |> put_change(:project_attribute_id, attr.name)

    Attribute.changeset(
      media,
      attr |> Map.put(:schema_field, :value),
      attrs,
      opts |> Keyword.put(:changeset, cs)
    )
  end
end
