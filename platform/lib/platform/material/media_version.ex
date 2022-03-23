defmodule Platform.Material.MediaVersion do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_versions" do
    field :file_location, :string
    field :file_size, :integer
    field :perceptual_hash, :binary, nullable: true
    field :source_url, :string
    field :type, Ecto.Enum, values: [:image, :video]
    field :thumbnail_location, :string

    belongs_to :media, Platform.Material.Media

    timestamps()
  end

  @doc false
  def changeset(media_version, attrs) do
    media_version
    |> cast(attrs, [:type, :perceptual_hash, :source_url, :file_size, :file_location])
    |> validate_required([:type, :source_url, :file_size, :file_location])
  end
end
