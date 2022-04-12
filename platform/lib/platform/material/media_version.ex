defmodule Platform.Material.MediaVersion do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Accounts
  alias __MODULE__

  schema "media_versions" do
    field :file_location, :string
    field :file_size, :integer
    field :duration_seconds, :integer
    field :perceptual_hash, :binary, nullable: true
    field :source_url, :string
    field :mime_type, :string
    field :client_name, :string
    field :thumbnail_location, :string
    field :hidden, :boolean, default: false

    belongs_to :media, Platform.Material.Media

    timestamps()
  end

  @doc false
  def changeset(media_version, attrs) do
    media_version
    |> cast(attrs, [
      :file_location,
      :file_size,
      :duration_seconds,
      :perceptual_hash,
      :source_url,
      :mime_type,
      :client_name,
      :media_id,
      :thumbnail_location,
      :hidden
    ])
    |> validate_required([
      :file_location,
      :file_size,
      :duration_seconds,
      :source_url,
      :mime_type,
      :client_name,
      :media_id,
      :thumbnail_location
    ])
  end

  @doc """
  Can the given user view the media version?
  """
  def can_user_view(%MediaVersion{} = version, %Accounts.User{} = user) do
    case version.hidden do
      true -> Accounts.is_privileged(user)
      false -> true
    end
  end
end
