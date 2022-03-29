defmodule Platform.Material.Media do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Utils

  @attr_sensitive ["Threatens Civilian Safety", "Graphic Violence"]

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
    |> validate_subset(:attr_sensitive, @attr_sensitive)
  end

  defp validate_slug(changeset) do
    changeset |> validate_format(:slug, ~r/^ATL-[A-Z0-9]{5}$/, message: "slug is not a valid code")
  end

  def attribute_options(attribute) do
    case attribute do
      :attr_sensitive -> @attr_sensitive
    end
  end
end
