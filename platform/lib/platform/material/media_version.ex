defmodule Platform.Material.MediaVersion do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media_versions" do
    field :file_location, :string
    field :file_size, :integer
    field :duration_seconds, :integer
    field :perceptual_hash, :binary, nullable: true
    field :source_url, :string
    field :mime_type, :string
    field :client_name, :string
    field :thumbnail_location, :string

    belongs_to :media, Platform.Material.Media

    timestamps()
  end

  @doc false
  def changeset(media_version, attrs) do
    media_version
    |> cast(attrs, [:file_location, :file_size, :duration_seconds, :perceptual_hash, :source_url, :mime_type, :client_name])
    |> validate_required([:file_location, :file_size, :duration_seconds, :source_url, :mime_type, :client_name])
  end
end
