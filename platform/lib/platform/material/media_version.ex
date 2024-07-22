defmodule Platform.Material.MediaVersion do
  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Material.Media

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "media_versions" do
    field(:upload_type, Ecto.Enum, values: [:user_provided, :direct], default: :user_provided)
    field(:source_url, :string)
    field(:metadata, :map, default: %{})

    embeds_many :artifacts, MediaVersionArtifact, primary_key: false do
      field(:id, :binary_id, primary_key: true, autogenerate: true)
      field(:file_location, :string)
      field(:file_hash_sha256, :string)
      field(:file_size, :integer)
      field(:mime_type, :string)
      field(:perceptual_hashes, :map, default: nil)
      field(:title, :string, default: nil)

      # No removed for artifacts (yet); in the interface, hidden is "minimized", but we call it hidden here for consistency with `MediaVersion`s.
      field(:visibility, Ecto.Enum, values: [:visible, :hidden], default: :visible)

      belongs_to(:uploading_token, Platform.API.APIToken, type: :binary_id)

      field(:type, Ecto.Enum,
        values: [:pdf, :media, :upload, :viewport, :fullpage, :wacz, :direct_file, :other],
        default: :other
      )

      timestamps()
    end

    field(:status, Ecto.Enum, values: [:pending, :complete, :error], default: :complete)
    field(:visibility, Ecto.Enum, default: :visible, values: [:visible, :hidden, :removed])

    # Virtual field for when creating new media versions (used by Updates)
    field(:explanation, :string, virtual: true)

    # Computed tsvector field "searchable"; we tell Ecto it's an array of maps so we can use it in queries
    field(:searchable, {:array, :map}, load_in_query: false)

    has_many(:media_associations, Platform.Material.MediaVersion.MediaVersionMedia,
      foreign_key: :media_version_id
    )

    has_many(:media, through: [:media_associations, :media])
    belongs_to(:project, Platform.Projects.Project, type: :binary_id)

    timestamps()
  end

  @doc false
  def changeset(media_version, attrs) do
    media_version
    |> cast(attrs, [
      :upload_type,
      :status,
      :source_url,
      :visibility,
      :project_id,
      :metadata,
      :explanation
    ])
    |> cast_embed(:artifacts, with: &artifact_changeset/2)
    |> validate_required([
      :status,
      :upload_type,
      :project_id
    ])
    |> validate_length(:explanation,
      max: 2500,
      message: "Explanations cannot exceed 2500 characters."
    )
    # Custom validation: if type is :direct, then :source_url is required (:when does NOT exist)
    |> then(fn changeset ->
      if get_field(changeset, :upload_type) == :direct do
        validate_required(changeset, [:source_url], message: "You must provide a URL to archive.")
      else
        changeset
      end
    end)
  end

  @doc false
  def artifact_changeset(artifact, attrs) do
    artifact
    |> cast(attrs, [
      :id,
      :file_location,
      :file_hash_sha256,
      :file_size,
      :mime_type,
      :perceptual_hashes,
      :type,
      :uploading_token_id,
      :visibility,
      :title
    ])
    |> validate_required([
      :file_location,
      :file_hash_sha256,
      :file_size,
      :mime_type,
      :type
    ])
  end
end

defmodule Platform.Material.MediaVersion.MediaVersionMedia do
  @moduledoc """
  Through-model for facilitating the many-to-many relationship between media and
  media versions.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias Platform.Material.Media
  alias Platform.Material.MediaVersion

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "media_version_media" do
    belongs_to(:media, Media, type: :binary_id)
    belongs_to(:media_version, MediaVersion, type: :binary_id)

    field(:scoped_id, :integer)
    timestamps()
  end

  def changeset(media_version_media, attrs) do
    media_version_media
    |> cast(attrs, [:media_version_id, :media_id, :scoped_id])
    |> validate_required([:media_version_id, :media_id, :scoped_id])
    |> unique_constraint([:media_id, :scoped_id],
      name: "media_version_media_media_id_scoped_id_index"
    )
    |> unique_constraint([:media_id, :scoped_id],
      name: "media_version_media_media_id_media_version_id_index"
    )
  end
end

defimpl Jason.Encoder, for: Platform.Material.MediaVersion do
  def encode(value, opts) do
    Jason.Encode.map(
      Map.take(value, [
        :id,
        :inserted_at,
        :scoped_id,
        :source_url,
        :status,
        :updated_at,
        :upload_type,
        :visibility,
        :metadata
      ])
      |> Map.put(:incident_ids, Enum.map(value.media, & &1.id))
      |> Enum.into(%{}, fn
        {key, %Ecto.Association.NotLoaded{}} -> {key, nil}
        {key, value} -> {key, value}
      end)
      |> Map.put(:artifacts, value.artifacts),
      opts
    )
  end
end

defimpl Jason.Encoder, for: Platform.Material.MediaVersion.MediaVersionArtifact do
  def encode(value, opts) do
    Jason.Encode.map(
      Map.take(value, [
        :id,
        :file_hash_sha256,
        :file_size,
        :mime_type,
        :perceptual_hashes,
        :type,
        :title,
        :visibility
      ])
      |> Enum.into(%{}, fn
        {key, %Ecto.Association.NotLoaded{}} -> {key, nil}
        {key, value} -> {key, value}
      end)
      |> Map.put(:access_url, Platform.Material.media_version_artifact_location(value)),
      opts
    )
  end
end
